"""YouTube download service using Cobalt API and yt-dlp"""

import yt_dlp
import os
import asyncio
from typing import Dict, Literal, AsyncGenerator
from pathlib import Path

from app.core.errors import (
    InvalidURLError,
    VideoUnavailableError,
    DownloadFailedError,
    ConversionFailedError,
    NetworkError,
    ServerError
)
from app.core.config import settings


class YTDLPService:
    """Service for interacting with yt-dlp"""

    @staticmethod
    async def get_metadata(url: str) -> Dict:
        """
        Fetch metadata from YouTube video

        Args:
            url: YouTube video or playlist URL

        Returns:
            Dictionary with metadata
        """
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,  # For playlists
            # Use multiple player clients with PO token
            'extractor_args': {
                'youtube': {
                    'player_client': ['ios', 'android', 'web'],
                    'skip': ['hls', 'dash'],
                    'player_skip': ['webpage'],
                    'po_token': 'web+MnYHNy4xLjEu0L5T',
                }
            },
        }

        try:
            # Run in executor to avoid blocking
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                lambda: YTDLPService._extract_info(url, ydl_opts)
            )

            # Check if playlist or single video
            if 'entries' in result:
                # Playlist
                return {
                    "type": "playlist",
                    "metadata": {
                        "title": result.get('title', 'Unknown Playlist'),
                        "videoCount": len(result['entries']),
                        "videos": [
                            {
                                "title": entry.get('title', 'Unknown'),
                                "url": entry.get('url', ''),
                                "duration": entry.get('duration', 0)
                            }
                            for entry in result['entries'][:10]  # Limit to 10 for preview
                        ]
                    }
                }
            else:
                # Single video
                duration = result.get('duration', 0)

                # Estimate file sizes (approximate)
                # MP3 320kbps ≈ 40KB/s, M4A 256kbps ≈ 32KB/s
                mp3_size = duration * 40 * 1024 if duration else 0
                m4a_size = duration * 32 * 1024 if duration else 0

                return {
                    "type": "video",
                    "metadata": {
                        "title": result.get('title', 'Unknown'),
                        "artist": result.get('uploader', result.get('channel', 'Unknown Artist')),
                        "duration": duration,
                        "thumbnail": result.get('thumbnail', ''),
                        "estimatedSize": {
                            "mp3": mp3_size,
                            "m4a": m4a_size
                        }
                    }
                }

        except yt_dlp.utils.DownloadError as e:
            error_msg = str(e).lower()
            if 'unavailable' in error_msg or 'private' in error_msg:
                raise VideoUnavailableError()
            elif 'url' in error_msg or 'invalid' in error_msg:
                raise InvalidURLError()
            else:
                raise NetworkError()
        except Exception as e:
            raise ServerError(str(e))

    @staticmethod
    async def download_audio(
        url: str,
        format: Literal["mp3", "m4a"] = "mp3"
    ) -> AsyncGenerator[bytes, None]:
        """
        Download and convert YouTube audio using yt-dlp

        Args:
            url: YouTube video URL
            format: Output format (mp3 or m4a)

        Yields:
            Audio file chunks (bytes)
        """
        # Create temp directory
        temp_dir = Path(settings.TEMP_DIR)
        temp_dir.mkdir(parents=True, exist_ok=True)

        # Generate unique filename
        import uuid
        temp_filename = temp_dir / f"{uuid.uuid4()}.{format}"

        # yt-dlp options with aggressive bypass techniques
        ydl_opts = {
            'format': 'bestaudio/best',
            'outtmpl': str(temp_filename.with_suffix('')),  # yt-dlp adds extension
            'quiet': False,  # Enable to see debug info
            'no_warnings': False,
            # Use multiple player clients with fallback strategy
            'extractor_args': {
                'youtube': {
                    'player_client': ['ios', 'android', 'web'],
                    'skip': ['hls', 'dash'],
                    'player_skip': ['webpage'],
                    'po_token': 'web+MnYHNy4xLjEu0L5T',  # PO Token for bypass
                }
            },
            'sleep_interval': 2,           # Sleep between downloads
            'max_sleep_interval': 5,       # Max sleep time
            'retries': 3,                   # Retry on failure
            'fragment_retries': 3,          # Fragment retries
        }

        # Format-specific options
        if format == "mp3":
            ydl_opts.update({
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '320',
                }],
            })
        elif format == "m4a":
            ydl_opts.update({
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'm4a',
                    'preferredquality': '256',
                }],
            })

        # Initialize downloaded_file before try block
        downloaded_file = None

        try:
            # Download the audio
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: YTDLPService._download_with_ytdlp(url, ydl_opts)
            )

            # Find the downloaded file (yt-dlp may add extension)
            for possible_file in [
                temp_filename,
                temp_filename.with_suffix(f'.{format}'),
                Path(str(temp_filename) + f'.{format}'),
            ]:
                if possible_file.exists():
                    downloaded_file = possible_file
                    break

            if not downloaded_file or not downloaded_file.exists():
                raise DownloadFailedError("File not found after download")

            # Stream the file in chunks
            CHUNK_SIZE = 64 * 1024  # 64KB chunks

            with open(downloaded_file, 'rb') as f:
                while True:
                    chunk = f.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    yield chunk

        except yt_dlp.utils.DownloadError as e:
            error_msg = str(e).lower()
            if 'unavailable' in error_msg:
                raise VideoUnavailableError()
            elif 'postprocessing' in error_msg or 'ffmpeg' in error_msg:
                raise ConversionFailedError(format)
            else:
                raise DownloadFailedError(str(e))
        except FileNotFoundError:
            raise DownloadFailedError("Output file not found")
        except Exception as e:
            raise ServerError(str(e))
        finally:
            # Cleanup: remove temporary file
            if downloaded_file and downloaded_file.exists():
                try:
                    downloaded_file.unlink()
                except:
                    pass  # Best effort cleanup

    @staticmethod
    def _extract_info(url: str, opts: Dict):
        """Helper to extract info with yt-dlp (blocking)"""
        with yt_dlp.YoutubeDL(opts) as ydl:
            return ydl.extract_info(url, download=False)

    @staticmethod
    def _download_with_ytdlp(url: str, opts: Dict):
        """Helper to download with yt-dlp (blocking)"""
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])

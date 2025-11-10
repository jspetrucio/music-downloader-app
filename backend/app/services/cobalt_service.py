"""Cobalt API service for downloading YouTube audio"""

import aiohttp
import asyncio
from typing import Dict, Optional, AsyncGenerator
from pathlib import Path

from app.core.errors import (
    DownloadFailedError,
    VideoUnavailableError,
    ServerError
)


class CobaltService:
    """Service for downloading audio using Cobalt API"""

    # Cobalt API endpoint
    COBALT_API_URL = "https://api.cobalt.tools/api/json"

    @staticmethod
    async def download_audio(url: str, format: str = "mp3") -> AsyncGenerator[bytes, None]:
        """
        Download audio using Cobalt API

        Args:
            url: YouTube video URL
            format: Audio format (mp3 or m4a)

        Yields:
            Audio file chunks (bytes)
        """
        # Cobalt API request payload
        payload = {
            "url": url,
            "vCodec": "h264",
            "vQuality": "720",
            "aFormat": format,  # mp3 or opus (m4a similar)
            "filenamePattern": "classic",
            "isAudioOnly": True,  # Audio only download
            "disableMetadata": False,
        }

        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        try:
            async with aiohttp.ClientSession() as session:
                # Step 1: Request download from Cobalt API
                async with session.post(
                    CobaltService.COBALT_API_URL,
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        raise DownloadFailedError(f"Cobalt API error: {error_text}")

                    result = await response.json()

                    # Check for errors
                    if result.get("status") == "error":
                        error_msg = result.get("text", "Unknown error")
                        if "unavailable" in error_msg.lower():
                            raise VideoUnavailableError()
                        raise DownloadFailedError(error_msg)

                    # Get download URL
                    download_url = result.get("url")
                    if not download_url:
                        raise DownloadFailedError("No download URL returned from Cobalt API")

                # Step 2: Download the audio file
                async with session.get(
                    download_url,
                    timeout=aiohttp.ClientTimeout(total=300)  # 5 min timeout
                ) as download_response:
                    if download_response.status != 200:
                        raise DownloadFailedError(f"Failed to download audio: HTTP {download_response.status}")

                    # Stream the file in chunks
                    CHUNK_SIZE = 64 * 1024  # 64KB chunks

                    async for chunk in download_response.content.iter_chunked(CHUNK_SIZE):
                        if chunk:
                            yield chunk

        except aiohttp.ClientError as e:
            raise DownloadFailedError(f"Network error: {str(e)}")
        except asyncio.TimeoutError:
            raise DownloadFailedError("Download timeout - video may be too large")
        except Exception as e:
            if isinstance(e, (DownloadFailedError, VideoUnavailableError)):
                raise
            raise ServerError(f"Unexpected error: {str(e)}")

    @staticmethod
    async def check_availability() -> bool:
        """
        Check if Cobalt API is available

        Returns:
            True if API is available, False otherwise
        """
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    "https://api.cobalt.tools/api/serverInfo",
                    timeout=aiohttp.ClientTimeout(total=5)
                ) as response:
                    return response.status == 200
        except:
            return False

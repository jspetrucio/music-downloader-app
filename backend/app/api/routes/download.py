"""Download API endpoint with streaming support"""

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import StreamingResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
import logging

from app.models.schemas import DownloadRequest
from app.services.ytdlp_service import YTDLPService

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)

router = APIRouter()


@router.post("/download")
@limiter.limit("10/minute")
async def download_audio(request: Request, body: DownloadRequest):
    """
    Download and convert YouTube audio to MP3 or M4A

    Rate limit: 10 requests per minute (to prevent abuse)

    Args:
        request: Starlette Request object (for rate limiting)
        body: DownloadRequest with URL and format

    Returns:
        StreamingResponse with audio file chunks

    Raises:
        InvalidURLError: Invalid YouTube URL
        VideoUnavailableError: Video is unavailable/private
        DownloadFailedError: Download failed
        ConversionFailedError: Audio conversion failed (ffmpeg issue)
        NetworkError: Network connection issue
        ServerError: Unexpected server error
    """
    logger.info(f"Download request - URL: {body.url}, Format: {body.format}")

    # Content type based on format
    content_types = {
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4"
    }

    # Get audio stream generator
    audio_stream = YTDLPService.download_audio(
        url=body.url,
        format=body.format
    )

    logger.info(f"Streaming {body.format} audio...")

    # Return streaming response with chunked transfer encoding
    return StreamingResponse(
        audio_stream,
        media_type=content_types[body.format],
        headers={
            "Content-Disposition": f'attachment; filename="audio.{body.format}"',
            "Cache-Control": "no-cache",
            "X-Content-Type-Options": "nosniff"
        }
    )

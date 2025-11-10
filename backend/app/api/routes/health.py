"""Health check endpoint"""

from fastapi import APIRouter
import yt_dlp
import shutil
import logging
from datetime import datetime

from app.models.schemas import HealthResponse

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint

    Verifies:
    - API is running
    - yt-dlp is available
    - ffmpeg is available (required for audio conversion)

    Returns:
        HealthResponse with service status
    """
    # Check yt-dlp version
    ytdlp_version = yt_dlp.version.__version__

    # Check if ffmpeg is available
    ffmpeg_available = shutil.which("ffmpeg") is not None

    status = "healthy" if ffmpeg_available else "degraded"

    if not ffmpeg_available:
        logger.warning("ffmpeg not found - audio conversion will fail!")

    return HealthResponse(
        status=status,
        timestamp=datetime.now().isoformat(),
        dependencies={
            "yt-dlp": ytdlp_version,
            "ffmpeg": "available" if ffmpeg_available else "missing"
        }
    )

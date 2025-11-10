"""Metadata API endpoint"""

from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
import logging

from app.models.schemas import MetadataRequest, MetadataResponse
from app.services.ytdlp_service import YTDLPService

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)

router = APIRouter()


@router.post("/metadata", response_model=MetadataResponse)
@limiter.limit("10/minute")
async def get_metadata(request: Request, body: MetadataRequest):
    """
    Get metadata from YouTube video or playlist

    Rate limit: 10 requests per minute

    Args:
        request: Starlette Request object (for rate limiting)
        body: MetadataRequest with URL

    Returns:
        MetadataResponse with video/playlist information

    Raises:
        InvalidURLError: Invalid YouTube URL
        VideoUnavailableError: Video is unavailable/private
        NetworkError: Network connection issue
        ServerError: Unexpected server error
    """
    logger.info(f"Fetching metadata for URL: {body.url}")

    # Call the service to get metadata
    result = await YTDLPService.get_metadata(body.url)

    logger.info(f"Metadata fetched successfully: type={result['type']}")

    return MetadataResponse(**result)

"""Pydantic models for request/response"""

from pydantic import BaseModel, HttpUrl, Field
from typing import Literal, Optional, List, Dict, Any
from datetime import datetime


class MetadataRequest(BaseModel):
    url: str = Field(..., description="YouTube video URL")


class MetadataResponse(BaseModel):
    type: Literal["video", "playlist"]
    metadata: dict

    class Config:
        json_schema_extra = {
            "example": {
                "type": "video",
                "metadata": {
                    "title": "Bohemian Rhapsody",
                    "artist": "Queen",
                    "duration": 355,
                    "thumbnail": "https://...",
                    "estimatedSize": {
                        "mp3": 8520000,
                        "m4a": 5680000
                    }
                }
            }
        }


class DownloadRequest(BaseModel):
    url: str = Field(..., description="YouTube video URL")
    format: Literal["mp3", "m4a"] = Field("mp3", description="Audio format")


class ErrorResponse(BaseModel):
    error: str
    code: str
    message: str

    class Config:
        json_schema_extra = {
            "example": {
                "error": "VideoUnavailableError",
                "code": "VIDEO_UNAVAILABLE",
                "message": "Vídeo indisponível ou privado"
            }
        }


class HealthResponse(BaseModel):
    status: str = "healthy"
    version: str = "1.0.0"


# MARK: - Queue Models

class QueueAddRequest(BaseModel):
    """Request to add item to queue"""
    url: str = Field(..., description="YouTube video URL")
    format: Literal["mp3", "m4a"] = Field("mp3", description="Audio format")
    priority: Optional[Literal["high", "normal", "low"]] = Field(
        "normal",
        description="Queue priority"
    )
    metadata: Optional[Dict[str, Any]] = Field(
        None,
        description="Optional metadata (title, artist, thumbnail, duration)"
    )


class QueueItemResponse(BaseModel):
    """Response for single queue item"""
    success: bool = True
    item: Dict[str, Any]


class QueueListResponse(BaseModel):
    """Response for queue list"""
    success: bool = True
    items: List[Dict[str, Any]]
    count: int


class QueueUpdatePriorityRequest(BaseModel):
    """Request to update item priority"""
    priority: Literal["high", "normal", "low"] = Field(..., description="New priority")


class QueueReorderRequest(BaseModel):
    """Request to manually reorder queue"""
    item_ids: List[str] = Field(..., description="Complete list of item IDs in desired order")


class SuccessResponse(BaseModel):
    """Generic success response"""
    success: bool = True
    message: str

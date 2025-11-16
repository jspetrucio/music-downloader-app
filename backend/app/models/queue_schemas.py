"""Pydantic schemas for queue API endpoints"""

from pydantic import BaseModel, Field, HttpUrl
from typing import Literal, Optional, List
from datetime import datetime
from enum import Enum


class QueuePriorityEnum(str, Enum):
    """Queue priority enumeration"""
    HIGH = "high"
    NORMAL = "normal"
    LOW = "low"


class QueueStatusEnum(str, Enum):
    """Queue status enumeration"""
    PENDING = "pending"
    DOWNLOADING = "downloading"
    COMPLETED = "completed"
    FAILED = "failed"
    PAUSED = "paused"
    CANCELLED = "cancelled"


class QueueDownloadRequest(BaseModel):
    """Request to add item to download queue"""
    url: str = Field(..., description="YouTube video URL")
    format: Literal["mp3", "m4a"] = Field("mp3", description="Audio format")
    priority: QueuePriorityEnum = Field(QueuePriorityEnum.NORMAL, description="Download priority")
    
    class Config:
        json_schema_extra = {
            "example": {
                "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "format": "mp3",
                "priority": "normal"
            }
        }


class QueueItemResponse(BaseModel):
    """Response for single queue item"""
    id: Optional[str] = None  # Can be string or int, iOS expects string
    url: str
    format: str
    priority: str
    status: str
    title: Optional[str] = None
    artist: Optional[str] = None
    duration: Optional[float] = None  # iOS expects float (seconds)
    thumbnail: Optional[str] = None
    progress: float = 0.0  # iOS expects 0.0-1.0 (not percentage!)
    current_retry: int = 0
    max_retries: int = 3
    error_message: Optional[str] = None
    error_code: Optional[str] = None
    file_path: Optional[str] = None
    file_size: Optional[int] = None
    created_at: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    updated_at: Optional[str] = None
    position: int = 0  # Position in queue (required by iOS)
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": 1,
                "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "format": "mp3",
                "priority": "normal",
                "status": "pending",
                "title": "Never Gonna Give You Up",
                "artist": "Rick Astley",
                "duration": 213,
                "thumbnail": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
                "progress": 0,
                "current_retry": 0,
                "max_retries": 3,
                "position": 5,
                "created_at": "2025-11-15T10:30:00",
                "updated_at": "2025-11-15T10:30:00"
            }
        }


class QueueItemCreateResponse(BaseModel):
    """Response when adding item to queue - wraps item in success structure for iOS"""
    success: bool = True
    item: QueueItemResponse

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "item": {
                    "id": "1",
                    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    "format": "mp3",
                    "priority": "normal",
                    "status": "pending",
                    "progress": 0.0,
                    "position": 1,
                    "title": "Never Gonna Give You Up",
                    "artist": "Rick Astley",
                    "duration": 213.0
                }
            }
        }


class QueueListResponse(BaseModel):
    """Response for listing queue items"""
    total: int
    items: List[QueueItemResponse]
    stats: dict
    
    class Config:
        json_schema_extra = {
            "example": {
                "total": 10,
                "items": [],
                "stats": {
                    "pending": 5,
                    "downloading": 3,
                    "completed": 2,
                    "failed": 0,
                    "paused": 0
                }
            }
        }


class PriorityUpdateRequest(BaseModel):
    """Request to update queue item priority"""
    priority: QueuePriorityEnum
    
    class Config:
        json_schema_extra = {
            "example": {
                "priority": "high"
            }
        }


class QueueOperationResponse(BaseModel):
    """Generic response for queue operations"""
    success: bool
    message: str
    item: Optional[QueueItemResponse] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Download paused successfully",
                "item": None
            }
        }

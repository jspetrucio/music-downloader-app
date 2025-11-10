"""Pydantic models for request/response"""

from pydantic import BaseModel, HttpUrl, Field
from typing import Literal, Optional


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

"""Database models for download queue system"""

from sqlalchemy import Column, Integer, String, DateTime, Enum as SQLEnum, JSON, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func
from datetime import datetime
from enum import Enum

Base = declarative_base()


class QueueStatus(str, Enum):
    """Download queue item status"""
    PENDING = "pending"
    DOWNLOADING = "downloading"
    COMPLETED = "completed"
    FAILED = "failed"
    PAUSED = "paused"
    CANCELLED = "cancelled"


class QueuePriority(str, Enum):
    """Download queue priority levels"""
    HIGH = "high"
    NORMAL = "normal"
    LOW = "low"


class DownloadQueueItem(Base):
    """Download queue item model"""
    __tablename__ = "download_queue"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    url = Column(String, nullable=False, index=True)
    format = Column(String, nullable=False)  # mp3 or m4a
    priority = Column(SQLEnum(QueuePriority), default=QueuePriority.NORMAL, nullable=False, index=True)
    status = Column(SQLEnum(QueueStatus), default=QueueStatus.PENDING, nullable=False, index=True)
    
    # Metadata
    title = Column(String, nullable=True)
    artist = Column(String, nullable=True)
    duration = Column(Integer, nullable=True)
    thumbnail = Column(String, nullable=True)
    
    # Progress tracking
    progress = Column(Integer, default=0)  # 0-100
    current_retry = Column(Integer, default=0)
    max_retries = Column(Integer, default=3)
    
    # Error tracking
    error_message = Column(String, nullable=True)
    error_code = Column(String, nullable=True)
    
    # File info
    file_path = Column(String, nullable=True)
    file_size = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Idempotency
    idempotency_key = Column(String, unique=True, nullable=True, index=True)
    
    def __repr__(self):
        return f"<DownloadQueueItem(id={self.id}, url={self.url}, status={self.status})>"

    def to_dict(self):
        """Convert model to dictionary - iOS compatible format"""
        return {
            "id": str(self.id),  # iOS expects string ID
            "url": self.url,
            "format": self.format,
            "priority": self.priority.value if isinstance(self.priority, QueuePriority) else self.priority,
            "status": self.status.value if isinstance(self.status, QueueStatus) else self.status,
            "title": self.title,
            "artist": self.artist,
            "duration": float(self.duration) if self.duration else None,  # iOS expects float
            "thumbnail": self.thumbnail,
            "progress": float(self.progress) / 100.0 if self.progress else 0.0,  # Convert 0-100 to 0.0-1.0 for iOS
            "current_retry": self.current_retry,
            "max_retries": self.max_retries,
            "error_message": self.error_message,
            "error_code": self.error_code,
            "file_path": self.file_path,
            "file_size": self.file_size,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

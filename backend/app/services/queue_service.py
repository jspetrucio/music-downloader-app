"""Download queue management service"""

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc, case
from typing import Optional, List, Dict
from datetime import datetime
import logging
import asyncio
from pathlib import Path
import uuid

from app.models.queue_models import DownloadQueueItem, QueueStatus, QueuePriority
from app.services.ytdlp_service import YTDLPService
from app.core.errors import InvalidURLError, VideoUnavailableError
from app.core.config import settings

logger = logging.getLogger(__name__)


class QueueService:
    """Service for managing download queue operations"""

    # Priority order mapping (higher number = higher priority)
    PRIORITY_ORDER = {
        QueuePriority.HIGH: 3,
        QueuePriority.NORMAL: 2,
        QueuePriority.LOW: 1
    }

    @staticmethod
    def add_to_queue(
        db: Session,
        url: str,
        format: str,
        priority: QueuePriority,
        idempotency_key: Optional[str] = None
    ) -> DownloadQueueItem:
        """
        Add a new item to the download queue
        
        Args:
            db: Database session
            url: YouTube video URL
            format: Audio format (mp3 or m4a)
            priority: Queue priority
            idempotency_key: Optional idempotency key for duplicate prevention
            
        Returns:
            Created queue item
        """
        # Check for duplicate idempotency key
        if idempotency_key:
            existing = db.query(DownloadQueueItem).filter(
                DownloadQueueItem.idempotency_key == idempotency_key
            ).first()
            if existing:
                logger.info(f"Returning cached queue item for idempotency key: {idempotency_key}")
                return existing

        # Create new queue item
        queue_item = DownloadQueueItem(
            url=url,
            format=format,
            priority=priority,
            status=QueueStatus.PENDING,
            idempotency_key=idempotency_key or str(uuid.uuid4())
        )

        db.add(queue_item)
        db.commit()
        db.refresh(queue_item)

        logger.info(f"Added item to queue: ID={queue_item.id}, URL={url}, Priority={priority}")
        return queue_item

    @staticmethod
    async def enrich_metadata(db: Session, item: DownloadQueueItem) -> DownloadQueueItem:
        """
        Fetch and add metadata to queue item
        
        Args:
            db: Database session
            item: Queue item to enrich
            
        Returns:
            Updated queue item with metadata
        """
        try:
            metadata = await YTDLPService.get_metadata(item.url)
            
            if metadata["type"] == "video":
                video_meta = metadata["metadata"]
                item.title = video_meta.get("title")
                item.artist = video_meta.get("artist")
                item.duration = video_meta.get("duration")
                item.thumbnail = video_meta.get("thumbnail")
                
            db.commit()
            db.refresh(item)
            
            logger.info(f"Enriched metadata for queue item {item.id}: {item.title}")
            
        except Exception as e:
            logger.warning(f"Failed to enrich metadata for item {item.id}: {e}")
            # Continue even if metadata fetch fails
            
        return item

    @staticmethod
    def get_queue_item(db: Session, item_id: int) -> Optional[DownloadQueueItem]:
        """Get queue item by ID"""
        return db.query(DownloadQueueItem).filter(DownloadQueueItem.id == item_id).first()

    @staticmethod
    def get_queue_position(db: Session, item_id: int) -> int:
        """
        Get position of item in queue (considering priority and creation time)

        Args:
            db: Database session
            item_id: Queue item ID

        Returns:
            Position in queue (1-based)
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item or item.status != QueueStatus.PENDING:
            return 0

        # Get numeric priority value for the item
        item_priority_value = QueueService.PRIORITY_ORDER[item.priority]

        # Create SQLAlchemy case expression to convert priority enum to numeric value
        priority_value = case(
            (DownloadQueueItem.priority == QueuePriority.HIGH, 3),
            (DownloadQueueItem.priority == QueuePriority.NORMAL, 2),
            (DownloadQueueItem.priority == QueuePriority.LOW, 1),
            else_=0
        )

        # Count items ahead in queue
        position = db.query(DownloadQueueItem).filter(
            and_(
                DownloadQueueItem.status == QueueStatus.PENDING,
                or_(
                    # Higher priority items
                    priority_value > item_priority_value,
                    # Same priority but created earlier
                    and_(
                        DownloadQueueItem.priority == item.priority,
                        DownloadQueueItem.created_at < item.created_at
                    )
                )
            )
        ).count()

        return position + 1

    @staticmethod
    def list_queue_items(
        db: Session,
        status: Optional[QueueStatus] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[DownloadQueueItem]:
        """
        List queue items with optional filtering
        
        Args:
            db: Database session
            status: Filter by status (optional)
            limit: Maximum items to return
            offset: Pagination offset
            
        Returns:
            List of queue items ordered by priority and creation time
        """
        query = db.query(DownloadQueueItem)
        
        if status:
            query = query.filter(DownloadQueueItem.status == status)
        
        # Order by priority (high to low) and creation time (oldest first)
        items = query.order_by(
            desc(DownloadQueueItem.priority),
            DownloadQueueItem.created_at
        ).limit(limit).offset(offset).all()
        
        return items

    @staticmethod
    def get_queue_stats(db: Session) -> Dict[str, int]:
        """Get queue statistics by status"""
        stats = {
            "pending": 0,
            "downloading": 0,
            "completed": 0,
            "failed": 0,
            "paused": 0,
            "cancelled": 0
        }
        
        for status in QueueStatus:
            count = db.query(DownloadQueueItem).filter(
                DownloadQueueItem.status == status
            ).count()
            stats[status.value] = count
            
        return stats

    @staticmethod
    def update_priority(
        db: Session,
        item_id: int,
        new_priority: QueuePriority
    ) -> Optional[DownloadQueueItem]:
        """
        Update queue item priority
        
        Args:
            db: Database session
            item_id: Queue item ID
            new_priority: New priority level
            
        Returns:
            Updated queue item or None if not found
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        # Can only change priority for pending items
        if item.status != QueueStatus.PENDING:
            logger.warning(f"Cannot change priority for item {item_id} with status {item.status}")
            return item
        
        old_priority = item.priority
        item.priority = new_priority
        db.commit()
        db.refresh(item)
        
        logger.info(f"Updated priority for item {item_id}: {old_priority} -> {new_priority}")
        return item

    @staticmethod
    def update_status(
        db: Session,
        item_id: int,
        new_status: QueueStatus,
        error_message: Optional[str] = None,
        error_code: Optional[str] = None
    ) -> Optional[DownloadQueueItem]:
        """
        Update queue item status
        
        Args:
            db: Database session
            item_id: Queue item ID
            new_status: New status
            error_message: Error message if failed
            error_code: Error code if failed
            
        Returns:
            Updated queue item or None if not found
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        item.status = new_status
        
        # Update timestamps based on status
        if new_status == QueueStatus.DOWNLOADING:
            item.started_at = datetime.utcnow()
            item.progress = 0
        elif new_status in [QueueStatus.COMPLETED, QueueStatus.FAILED, QueueStatus.CANCELLED]:
            item.completed_at = datetime.utcnow()
            if new_status == QueueStatus.COMPLETED:
                item.progress = 100
        
        # Update error information
        if new_status == QueueStatus.FAILED:
            item.error_message = error_message
            item.error_code = error_code
        
        db.commit()
        db.refresh(item)
        
        logger.info(f"Updated status for item {item_id}: {new_status}")
        return item

    @staticmethod
    def update_progress(db: Session, item_id: int, progress: int) -> Optional[DownloadQueueItem]:
        """
        Update download progress (0-100)
        
        Args:
            db: Database session
            item_id: Queue item ID
            progress: Progress percentage (0-100)
            
        Returns:
            Updated queue item or None if not found
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        item.progress = max(0, min(100, progress))  # Clamp to 0-100
        db.commit()
        db.refresh(item)
        
        return item

    @staticmethod
    def pause_download(db: Session, item_id: int) -> Optional[DownloadQueueItem]:
        """
        Pause a download (only if pending or downloading)
        
        Args:
            db: Database session
            item_id: Queue item ID
            
        Returns:
            Updated queue item or None if not found/cannot pause
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        if item.status in [QueueStatus.PENDING, QueueStatus.DOWNLOADING]:
            item.status = QueueStatus.PAUSED
            db.commit()
            db.refresh(item)
            logger.info(f"Paused item {item_id}")
            return item
        
        logger.warning(f"Cannot pause item {item_id} with status {item.status}")
        return None

    @staticmethod
    def resume_download(db: Session, item_id: int) -> Optional[DownloadQueueItem]:
        """
        Resume a paused download
        
        Args:
            db: Database session
            item_id: Queue item ID
            
        Returns:
            Updated queue item or None if not found/cannot resume
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        if item.status == QueueStatus.PAUSED:
            item.status = QueueStatus.PENDING
            db.commit()
            db.refresh(item)
            logger.info(f"Resumed item {item_id}")
            return item
        
        logger.warning(f"Cannot resume item {item_id} with status {item.status}")
        return None

    @staticmethod
    def delete_queue_item(db: Session, item_id: int) -> bool:
        """
        Delete queue item (only if not currently downloading)
        
        Args:
            db: Database session
            item_id: Queue item ID
            
        Returns:
            True if deleted, False otherwise
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return False
        
        # Cannot delete items currently being downloaded
        if item.status == QueueStatus.DOWNLOADING:
            logger.warning(f"Cannot delete item {item_id} while downloading")
            return False
        
        # Clean up file if exists
        if item.file_path and Path(item.file_path).exists():
            try:
                Path(item.file_path).unlink()
                logger.info(f"Deleted file: {item.file_path}")
            except Exception as e:
                logger.warning(f"Failed to delete file {item.file_path}: {e}")
        
        db.delete(item)
        db.commit()
        logger.info(f"Deleted queue item {item_id}")
        return True

    @staticmethod
    def increment_retry(db: Session, item_id: int) -> Optional[DownloadQueueItem]:
        """
        Increment retry counter for failed download
        
        Args:
            db: Database session
            item_id: Queue item ID
            
        Returns:
            Updated queue item or None if max retries reached
        """
        item = QueueService.get_queue_item(db, item_id)
        if not item:
            return None
        
        item.current_retry += 1
        
        if item.current_retry >= item.max_retries:
            # Max retries reached, mark as failed
            item.status = QueueStatus.FAILED
            logger.warning(f"Item {item_id} reached max retries ({item.max_retries})")
        else:
            # Reset to pending for retry
            item.status = QueueStatus.PENDING
            item.error_message = None
            item.error_code = None
            logger.info(f"Item {item_id} retry {item.current_retry}/{item.max_retries}")
        
        db.commit()
        db.refresh(item)
        return item

    @staticmethod
    def get_next_pending_item(db: Session) -> Optional[DownloadQueueItem]:
        """
        Get next pending item based on priority and creation time
        
        Returns:
            Next queue item to process or None if queue is empty
        """
        item = db.query(DownloadQueueItem).filter(
            DownloadQueueItem.status == QueueStatus.PENDING
        ).order_by(
            desc(DownloadQueueItem.priority),
            DownloadQueueItem.created_at
        ).first()
        
        return item

    @staticmethod
    def get_downloading_count(db: Session) -> int:
        """Get count of items currently being downloaded"""
        return db.query(DownloadQueueItem).filter(
            DownloadQueueItem.status == QueueStatus.DOWNLOADING
        ).count()

    @staticmethod
    def cleanup_old_completed(db: Session, days: int = 7) -> int:
        """
        Clean up completed/failed items older than specified days
        
        Args:
            db: Database session
            days: Delete items older than this many days
            
        Returns:
            Number of items deleted
        """
        from datetime import timedelta
        
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        items = db.query(DownloadQueueItem).filter(
            and_(
                DownloadQueueItem.status.in_([QueueStatus.COMPLETED, QueueStatus.FAILED, QueueStatus.CANCELLED]),
                DownloadQueueItem.completed_at < cutoff_date
            )
        ).all()
        
        count = 0
        for item in items:
            # Clean up file if exists
            if item.file_path and Path(item.file_path).exists():
                try:
                    Path(item.file_path).unlink()
                except Exception:
                    pass
            
            db.delete(item)
            count += 1
        
        db.commit()
        logger.info(f"Cleaned up {count} old queue items")
        return count

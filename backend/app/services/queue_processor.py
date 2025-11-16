"""Background queue processor for handling downloads"""

import asyncio
import logging
from pathlib import Path
from typing import Optional
from datetime import datetime
import uuid

from app.core.database import get_db_context
from app.models.queue_models import QueueStatus, DownloadQueueItem
from app.services.queue_service import QueueService
from app.services.ytdlp_service import YTDLPService
from app.core.errors import MusicDownloaderException
from app.core.config import settings

logger = logging.getLogger(__name__)


class QueueProcessor:
    """Background processor for download queue"""
    
    def __init__(self, max_concurrent: int = 3):
        """
        Initialize queue processor
        
        Args:
            max_concurrent: Maximum concurrent downloads (default: 3)
        """
        self.max_concurrent = max_concurrent
        self.is_running = False
        self.tasks = []
        self.current_downloads = set()  # Track active download IDs
        
    async def start(self):
        """Start the queue processor"""
        if self.is_running:
            logger.warning("Queue processor already running")
            return
        
        self.is_running = True
        logger.info(f"Queue processor started (max concurrent: {self.max_concurrent})")
        
        # Start the main processing loop
        asyncio.create_task(self._process_loop())
        
    async def stop(self):
        """Stop the queue processor gracefully"""
        logger.info("Stopping queue processor...")
        self.is_running = False
        
        # Cancel all running tasks
        for task in self.tasks:
            if not task.done():
                task.cancel()
        
        # Wait for tasks to complete
        if self.tasks:
            await asyncio.gather(*self.tasks, return_exceptions=True)
        
        logger.info("Queue processor stopped")
        
    async def _process_loop(self):
        """Main processing loop"""
        while self.is_running:
            try:
                await self._process_queue()
                await asyncio.sleep(2)  # Check queue every 2 seconds
            except Exception as e:
                logger.exception(f"Error in queue processing loop: {e}")
                await asyncio.sleep(5)  # Wait longer on error
                
    async def _process_queue(self):
        """Process queue items"""
        # Clean up completed tasks
        self.tasks = [t for t in self.tasks if not t.done()]
        
        # Check if we can start more downloads
        with get_db_context() as db:
            current_downloading = QueueService.get_downloading_count(db)
            available_slots = self.max_concurrent - current_downloading
            
            if available_slots <= 0:
                return  # Queue is full
            
            # Get next pending items
            for _ in range(available_slots):
                next_item = QueueService.get_next_pending_item(db)
                
                if not next_item:
                    break  # No more pending items
                
                # Avoid duplicate processing
                if next_item.id in self.current_downloads:
                    continue
                
                # Mark as downloading
                QueueService.update_status(db, next_item.id, QueueStatus.DOWNLOADING)
                self.current_downloads.add(next_item.id)
                
                # Start download task
                task = asyncio.create_task(self._process_item(next_item.id))
                self.tasks.append(task)
                
                logger.info(f"Started processing queue item {next_item.id}")
                
    async def _process_item(self, item_id: int):
        """
        Process a single queue item
        
        Args:
            item_id: Queue item ID to process
        """
        try:
            with get_db_context() as db:
                item = QueueService.get_queue_item(db, item_id)
                if not item:
                    logger.error(f"Queue item {item_id} not found")
                    return
                
                logger.info(f"Processing queue item {item_id}: {item.url}")
                
                # Download the audio
                await self._download_audio(db, item)
                
        except MusicDownloaderException as e:
            # Handle known errors
            await self._handle_error(item_id, e.code, e.message)
            
        except Exception as e:
            # Handle unexpected errors
            logger.exception(f"Unexpected error processing item {item_id}: {e}")
            await self._handle_error(item_id, "UNKNOWN_ERROR", str(e))
            
        finally:
            # Remove from current downloads
            self.current_downloads.discard(item_id)
            
    async def _download_audio(self, db, item: DownloadQueueItem):
        """
        Download audio for queue item
        
        Args:
            db: Database session
            item: Queue item to process
        """
        # Create download directory
        download_dir = Path(settings.TEMP_DIR) / "queue_downloads"
        download_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate unique filename
        filename = f"{uuid.uuid4()}.{item.format}"
        temp_file = download_dir / filename
        
        try:
            # Update progress
            QueueService.update_progress(db, item.id, 10)
            
            # Get audio stream from yt-dlp
            logger.info(f"Starting download for item {item.id}")
            
            # Configure yt-dlp options
            ydl_opts = {
                'format': 'bestaudio/best',
                'outtmpl': str(temp_file.with_suffix('')),
                'quiet': False,
                'no_warnings': False,
                'extractor_args': {
                    'youtube': {
                        'player_client': ['ios', 'android', 'web'],
                        'skip': ['hls', 'dash'],
                        'player_skip': ['webpage'],
                        'po_token': 'web+MnYHNy4xLjEu0L5T',
                    }
                },
                'retries': 3,
                'fragment_retries': 3,
            }
            
            # Format-specific options
            if item.format == "mp3":
                ydl_opts['postprocessors'] = [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '320',
                }]
            elif item.format == "m4a":
                ydl_opts['postprocessors'] = [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'm4a',
                    'preferredquality': '256',
                }]
            
            # Progress hook
            def progress_hook(d):
                if d['status'] == 'downloading':
                    # Extract progress percentage
                    if 'downloaded_bytes' in d and 'total_bytes' in d:
                        progress = int((d['downloaded_bytes'] / d['total_bytes']) * 90)
                        QueueService.update_progress(db, item.id, progress)
                elif d['status'] == 'finished':
                    QueueService.update_progress(db, item.id, 95)
            
            ydl_opts['progress_hooks'] = [progress_hook]
            
            # Download using yt-dlp
            import yt_dlp
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                # Extract info first (also enriches metadata)
                info = ydl.extract_info(item.url, download=False)
                
                # Update metadata if not already set
                if not item.title:
                    item.title = info.get('title', 'Unknown')
                    item.artist = info.get('uploader', info.get('channel', 'Unknown'))
                    item.duration = info.get('duration', 0)
                    item.thumbnail = info.get('thumbnail', '')
                    db.commit()
                
                # Download the file
                ydl.download([item.url])
            
            # Find downloaded file
            downloaded_file = None
            for possible_file in [
                temp_file,
                temp_file.with_suffix(f'.{item.format}'),
                Path(str(temp_file) + f'.{item.format}'),
            ]:
                if possible_file.exists():
                    downloaded_file = possible_file
                    break
            
            if not downloaded_file or not downloaded_file.exists():
                raise Exception("Downloaded file not found")
            
            # Update item with file info
            item.file_path = str(downloaded_file)
            item.file_size = downloaded_file.stat().st_size
            item.progress = 100
            item.status = QueueStatus.COMPLETED
            item.completed_at = datetime.utcnow()
            db.commit()
            
            logger.info(f"Download completed for item {item.id}: {downloaded_file}")
            
        except Exception as e:
            # Clean up partial download
            if temp_file.exists():
                temp_file.unlink()
            raise
            
    async def _handle_error(self, item_id: int, error_code: str, error_message: str):
        """
        Handle download error with retry logic
        
        Args:
            item_id: Queue item ID
            error_code: Error code
            error_message: Error message
        """
        with get_db_context() as db:
            item = QueueService.get_queue_item(db, item_id)
            if not item:
                return
            
            logger.error(f"Error processing item {item_id}: {error_code} - {error_message}")
            
            # Check if we should retry
            if item.current_retry < item.max_retries:
                # Increment retry and reset to pending
                QueueService.increment_retry(db, item_id)
                logger.info(f"Retrying item {item_id} (attempt {item.current_retry + 1}/{item.max_retries})")
            else:
                # Max retries reached, mark as failed
                item.status = QueueStatus.FAILED
                item.error_code = error_code
                item.error_message = error_message
                item.completed_at = datetime.utcnow()
                db.commit()
                logger.error(f"Item {item_id} failed after {item.max_retries} retries")


# Global queue processor instance
_queue_processor: Optional[QueueProcessor] = None


def get_queue_processor() -> QueueProcessor:
    """Get or create global queue processor instance"""
    global _queue_processor
    if _queue_processor is None:
        _queue_processor = QueueProcessor(max_concurrent=3)
    return _queue_processor


async def start_queue_processor():
    """Start the global queue processor"""
    processor = get_queue_processor()
    await processor.start()
    logger.info("Global queue processor started")


async def stop_queue_processor():
    """Stop the global queue processor"""
    global _queue_processor
    if _queue_processor:
        await _queue_processor.stop()
        _queue_processor = None
        logger.info("Global queue processor stopped")

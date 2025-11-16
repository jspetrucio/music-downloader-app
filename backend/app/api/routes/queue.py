"""Queue management API endpoints"""

from fastapi import APIRouter, HTTPException, Request, Depends, Header
from sqlalchemy.orm import Session
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Optional, List
import logging

from app.models.queue_schemas import (
    QueueDownloadRequest,
    QueueItemResponse,
    QueueItemCreateResponse,
    QueueListResponse,
    PriorityUpdateRequest,
    QueueOperationResponse,
    QueuePriorityEnum,
    QueueStatusEnum
)
from app.models.queue_models import QueuePriority, QueueStatus
from app.services.queue_service import QueueService
from app.core.database import get_db
from app.core.errors import MusicDownloaderException

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)

router = APIRouter()


@router.post("/downloads/queue", response_model=QueueItemCreateResponse, status_code=201)
@limiter.limit("20/minute")
async def add_to_queue(
    request: Request,
    body: QueueDownloadRequest,
    db: Session = Depends(get_db),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key")
):
    """
    Add a download to the queue
    
    Rate limit: 20 requests per minute
    
    **Idempotency**: Include `Idempotency-Key` header to prevent duplicate queue items.
    Same key within 24 hours returns the same queue item.
    
    **Priority Levels**:
    - `high`: Downloads first, before normal and low priority items
    - `normal`: Standard priority (default)
    - `low`: Downloads after higher priority items
    
    **Queue Processing**:
    - Maximum 3 concurrent downloads
    - Items processed by priority, then creation time (FIFO within same priority)
    - Failed downloads auto-retry up to 3 times
    
    Args:
        request: Starlette Request object (for rate limiting)
        body: Queue download request
        db: Database session
        idempotency_key: Optional idempotency key for duplicate prevention
        
    Returns:
        Queue item with ID and position
        
    Raises:
        400: Invalid URL or parameters
        429: Rate limit exceeded
        500: Server error
    """
    try:
        # Convert priority enum to model enum
        priority = QueuePriority(body.priority.value)
        
        # Add to queue
        item = QueueService.add_to_queue(
            db=db,
            url=body.url,
            format=body.format,
            priority=priority,
            idempotency_key=idempotency_key
        )

        # Metadata will be enriched by queue processor in background
        # (Removed asyncio.create_task to avoid database session conflicts)

        # Get position in queue
        position = QueueService.get_queue_position(db, item.id)

        logger.info(f"Added to queue: ID={item.id}, Position={position}")

        # Build item dict with all fields iOS expects
        item_dict = item.to_dict()
        item_dict['position'] = position  # Add position to response

        # Create QueueItemResponse from dict
        item_response = QueueItemResponse(**item_dict)

        # Wrap in success structure for iOS
        return QueueItemCreateResponse(
            success=True,
            item=item_response
        )
        
    except MusicDownloaderException as e:
        raise HTTPException(status_code=e.status_code, detail={
            "error": e.__class__.__name__,
            "code": e.code,
            "message": e.message
        })
    except Exception as e:
        logger.exception(f"Error adding to queue: {e}")
        raise HTTPException(status_code=500, detail={
            "error": "ServerError",
            "code": "SERVER_ERROR",
            "message": "Failed to add item to queue"
        })


@router.get("/downloads/queue", response_model=QueueListResponse)
@limiter.limit("30/minute")
async def list_queue(
    request: Request,
    status: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """
    List all queue items with optional filtering
    
    Rate limit: 30 requests per minute
    
    **Query Parameters**:
    - `status`: Filter by status (pending, downloading, completed, failed, paused, cancelled)
    - `limit`: Maximum items to return (default: 100, max: 500)
    - `offset`: Pagination offset (default: 0)
    
    **Response includes**:
    - List of queue items ordered by priority and creation time
    - Total count
    - Statistics by status
    
    Args:
        request: Starlette Request object
        status: Optional status filter
        limit: Maximum items to return
        offset: Pagination offset
        db: Database session
        
    Returns:
        List of queue items with statistics
    """
    try:
        # Validate and convert status
        status_filter = None
        if status:
            try:
                status_filter = QueueStatus(status)
            except ValueError:
                raise HTTPException(status_code=400, detail={
                    "error": "ValidationError",
                    "code": "INVALID_STATUS",
                    "message": f"Invalid status: {status}. Must be one of: {', '.join([s.value for s in QueueStatus])}"
                })
        
        # Validate limit
        limit = min(max(1, limit), 500)  # Clamp between 1 and 500
        
        # Get queue items
        items = QueueService.list_queue_items(
            db=db,
            status=status_filter,
            limit=limit,
            offset=offset
        )
        
        # Get total count
        total = len(items) if status_filter else db.query(
            __import__('app.models.queue_models', fromlist=['DownloadQueueItem']).DownloadQueueItem
        ).count()
        
        # Get statistics
        stats = QueueService.get_queue_stats(db)
        
        # Convert to response models with positions
        items_response = []
        for item in items:
            item_dict = item.to_dict()
            # Add position if pending
            if item.status == QueueStatus.PENDING:
                item_dict['position'] = QueueService.get_queue_position(db, item.id)
            items_response.append(QueueItemResponse(**item_dict))
        
        return QueueListResponse(
            total=total,
            items=items_response,
            stats=stats
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error listing queue: {e}")
        raise HTTPException(status_code=500, detail={
            "error": "ServerError",
            "code": "SERVER_ERROR",
            "message": "Failed to list queue items"
        })


@router.get("/downloads/queue/{item_id}", response_model=QueueItemResponse)
@limiter.limit("60/minute")
async def get_queue_item(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Get specific queue item by ID
    
    Rate limit: 60 requests per minute
    
    **Use this endpoint to**:
    - Poll download progress (check `progress` field)
    - Monitor status changes
    - Get error details if failed
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session
        
    Returns:
        Queue item details with current status and progress
        
    Raises:
        404: Item not found
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    item_dict = item.to_dict()
    
    # Add position if pending
    if item.status == QueueStatus.PENDING:
        item_dict['position'] = QueueService.get_queue_position(db, item.id)
    
    return QueueItemResponse(**item_dict)


@router.put("/downloads/queue/{item_id}/priority", response_model=QueueOperationResponse)
@limiter.limit("10/minute")
async def update_priority(
    request: Request,
    item_id: int,
    body: PriorityUpdateRequest,
    db: Session = Depends(get_db)
):
    """
    Update queue item priority
    
    Rate limit: 10 requests per minute
    
    **Priority can only be changed for pending items.**
    Changing priority will affect the item's position in the queue.
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        body: Priority update request
        db: Database session
        
    Returns:
        Operation result with updated item
        
    Raises:
        404: Item not found
        400: Cannot change priority (item not pending)
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    if item.status != QueueStatus.PENDING:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "CANNOT_CHANGE_PRIORITY",
            "message": f"Cannot change priority for item with status: {item.status.value}"
        })
    
    # Update priority
    priority = QueuePriority(body.priority.value)
    updated_item = QueueService.update_priority(db, item_id, priority)
    
    item_dict = updated_item.to_dict()
    item_dict['position'] = QueueService.get_queue_position(db, updated_item.id)
    
    return QueueOperationResponse(
        success=True,
        message=f"Priority updated to {body.priority.value}",
        item=QueueItemResponse(**item_dict)
    )


@router.delete("/downloads/queue/{item_id}", response_model=QueueOperationResponse)
@limiter.limit("10/minute")
async def remove_from_queue(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Remove item from queue
    
    Rate limit: 10 requests per minute
    
    **Cannot delete items currently being downloaded.**
    Use pause endpoint first if you need to stop an active download.
    
    This will also delete the downloaded file if it exists.
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session
        
    Returns:
        Operation result
        
    Raises:
        404: Item not found
        400: Cannot delete (item is downloading)
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    if item.status == QueueStatus.DOWNLOADING:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "CANNOT_DELETE_DOWNLOADING",
            "message": "Cannot delete item while downloading. Pause first."
        })
    
    # Delete the item
    success = QueueService.delete_queue_item(db, item_id)
    
    if not success:
        raise HTTPException(status_code=500, detail={
            "error": "ServerError",
            "code": "DELETE_FAILED",
            "message": "Failed to delete queue item"
        })
    
    return QueueOperationResponse(
        success=True,
        message=f"Queue item {item_id} deleted successfully"
    )


@router.post("/downloads/queue/{item_id}/pause", response_model=QueueOperationResponse)
@limiter.limit("10/minute")
async def pause_download(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Pause a download
    
    Rate limit: 10 requests per minute
    
    **Can only pause pending or downloading items.**
    Paused items will not be processed until resumed.
    
    Note: Currently downloading items will complete their current download
    before pausing. This is a limitation of the yt-dlp library.
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session
        
    Returns:
        Operation result with updated item
        
    Raises:
        404: Item not found
        400: Cannot pause (invalid status)
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    if item.status not in [QueueStatus.PENDING, QueueStatus.DOWNLOADING]:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "CANNOT_PAUSE",
            "message": f"Cannot pause item with status: {item.status.value}"
        })
    
    # Pause the item
    updated_item = QueueService.pause_download(db, item_id)
    
    if not updated_item:
        raise HTTPException(status_code=500, detail={
            "error": "ServerError",
            "code": "PAUSE_FAILED",
            "message": "Failed to pause download"
        })
    
    return QueueOperationResponse(
        success=True,
        message="Download paused successfully",
        item=QueueItemResponse(**updated_item.to_dict())
    )


@router.post("/downloads/queue/{item_id}/resume", response_model=QueueOperationResponse)
@limiter.limit("10/minute")
async def resume_download(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Resume a paused download
    
    Rate limit: 10 requests per minute
    
    **Can only resume paused items.**
    Resumed items will be added back to the queue based on their priority.
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session
        
    Returns:
        Operation result with updated item and new position
        
    Raises:
        404: Item not found
        400: Cannot resume (not paused)
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    if item.status != QueueStatus.PAUSED:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "CANNOT_RESUME",
            "message": f"Cannot resume item with status: {item.status.value}"
        })
    
    # Resume the item
    updated_item = QueueService.resume_download(db, item_id)
    
    if not updated_item:
        raise HTTPException(status_code=500, detail={
            "error": "ServerError",
            "code": "RESUME_FAILED",
            "message": "Failed to resume download"
        })
    
    item_dict = updated_item.to_dict()
    item_dict['position'] = QueueService.get_queue_position(db, updated_item.id)
    
    return QueueOperationResponse(
        success=True,
        message=f"Download resumed and added to queue at position {item_dict['position']}",
        item=QueueItemResponse(**item_dict)
    )


@router.post("/downloads/queue/{item_id}/retry", response_model=QueueOperationResponse)
@limiter.limit("10/minute")
async def retry_failed_download(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Manually retry a failed download
    
    Rate limit: 10 requests per minute
    
    **Can only retry failed items.**
    This will reset the item to pending status and add it back to the queue.
    The retry counter is NOT reset, so item still has limited retries.
    
    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session
        
    Returns:
        Operation result with updated item
        
    Raises:
        404: Item not found
        400: Cannot retry (not failed or max retries reached)
    """
    item = QueueService.get_queue_item(db, item_id)
    
    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })
    
    if item.status != QueueStatus.FAILED:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "CANNOT_RETRY",
            "message": f"Can only retry failed items. Current status: {item.status.value}"
        })
    
    if item.current_retry >= item.max_retries:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "MAX_RETRIES_REACHED",
            "message": f"Maximum retries ({item.max_retries}) already reached"
        })
    
    # Reset to pending
    item.status = QueueStatus.PENDING
    item.error_message = None
    item.error_code = None
    db.commit()
    db.refresh(item)
    
    item_dict = item.to_dict()
    item_dict['position'] = QueueService.get_queue_position(db, item.id)
    
    return QueueOperationResponse(
        success=True,
        message=f"Download retry scheduled at position {item_dict['position']}",
        item=QueueItemResponse(**item_dict)
    )


@router.get("/downloads/queue/{item_id}/file")
@limiter.limit("30/minute")
async def download_queue_file(
    request: Request,
    item_id: int,
    db: Session = Depends(get_db)
):
    """
    Download the completed audio file from a queue item

    Rate limit: 30 requests per minute

    **Can only download files from completed queue items.**
    Returns the audio file as a downloadable attachment.

    Args:
        request: Starlette Request object
        item_id: Queue item ID
        db: Database session

    Returns:
        FileResponse with the audio file

    Raises:
        404: Item not found or file not found
        400: Item not completed yet
    """
    from fastapi.responses import FileResponse
    import os

    item = QueueService.get_queue_item(db, item_id)

    if not item:
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "ITEM_NOT_FOUND",
            "message": f"Queue item {item_id} not found"
        })

    if item.status != QueueStatus.COMPLETED:
        raise HTTPException(status_code=400, detail={
            "error": "InvalidOperation",
            "code": "NOT_COMPLETED",
            "message": f"Cannot download file from item with status: {item.status.value}"
        })

    if not item.file_path or not os.path.exists(item.file_path):
        raise HTTPException(status_code=404, detail={
            "error": "NotFound",
            "code": "FILE_NOT_FOUND",
            "message": "Downloaded file not found on server"
        })

    # Determine content type
    content_types = {
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4"
    }

    # Get filename for download (sanitize to avoid header issues)
    import re
    from urllib.parse import quote

    # Remove unsafe characters for filename
    safe_title = item.title or 'audio'
    # Remove emojis and special characters that might break HTTP headers
    safe_title = re.sub(r'[^\w\s\-\.]', '', safe_title)
    # Replace multiple spaces with single space
    safe_title = re.sub(r'\s+', ' ', safe_title).strip()
    # Limit length
    if len(safe_title) > 200:
        safe_title = safe_title[:200]

    filename = f"{safe_title}.{item.format}"
    # URL encode for Content-Disposition header (RFC 6266)
    filename_encoded = quote(filename)

    return FileResponse(
        path=item.file_path,
        media_type=content_types.get(item.format, "application/octet-stream"),
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{filename_encoded}",
            "Cache-Control": "no-cache"
        }
    )

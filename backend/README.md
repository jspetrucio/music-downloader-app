# Music Downloader API - Backend

FastAPI backend service for downloading and converting YouTube videos to audio formats (MP3/M4A).

## Features

### Core Features
- YouTube video/playlist metadata extraction
- Audio download and conversion (MP3 320kbps, M4A 256kbps)
- Streaming chunked responses (no timeout issues)
- Rate limiting protection
- CORS enabled for iOS app connectivity
- Comprehensive error handling
- Health check endpoint
- **Docker support for easy deployment**

### Queue System (NEW in v2.0)
- **Priority-based queue**: High, normal, low priority downloads
- **Background processing**: Up to 3 concurrent downloads
- **Progress tracking**: Real-time progress updates (0-100%)
- **Auto-retry**: Failed downloads automatically retry up to 3 times
- **Persistent queue**: Survives server restarts (SQLite database)
- **Pause/Resume**: Control downloads dynamically
- **Idempotency**: Prevents duplicate queue items

## Tech Stack

- **FastAPI**: Modern async web framework
- **yt-dlp**: YouTube download engine
- **ffmpeg**: Audio conversion
- **slowapi**: Rate limiting
- **pydantic**: Data validation
- **SQLAlchemy**: Database ORM for queue management
- **SQLite**: Queue persistence

## Quick Start (Docker - Recommended)

The fastest way to run the backend is using Docker:

```bash
cd backend

# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Test it's working
curl http://localhost:8000/health
```

Server will be available at: **http://localhost:8000**

For detailed Docker documentation, see **[DOCKER.md](DOCKER.md)**

## Alternative: Local Development Setup

### Prerequisites

1. **Python 3.11+**
   ```bash
   python3 --version
   ```

2. **ffmpeg** (required for audio conversion)
   ```bash
   # macOS
   brew install ffmpeg

   # Verify installation
   ffmpeg -version
   ```

3. **yt-dlp** (installed via requirements.txt)

### Setup Steps

#### 1. Create Virtual Environment

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
```

#### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

#### 3. Create .env File

```bash
cp .env.example .env
```

Edit `.env` if needed (defaults work for local development):

```env
HOST=0.0.0.0
PORT=8000
DEBUG=True

# CORS - Allow iOS Simulator and localhost
CORS_ORIGINS=http://localhost:*,http://127.0.0.1:*

# Rate Limits
METADATA_RATE_LIMIT=10/minute
DOWNLOAD_RATE_LIMIT=1/minute

# Storage
MAX_FILE_SIZE_MB=50
TEMP_DIR=/tmp/music_downloader
```

#### 4. Run the Server

```bash
# Development mode (auto-reload)
python main.py

# Or using uvicorn directly
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server will start at: **http://localhost:8000**

## API Endpoints

### Health Check

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:00",
  "version": "2.0.0"
}
```

### Get Metadata

**Endpoint:** `POST /api/v1/metadata`

**Rate Limit:** 10 requests/minute

```bash
curl -X POST http://localhost:8000/api/v1/metadata \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  }'
```

Response:
```json
{
  "type": "video",
  "metadata": {
    "title": "Rick Astley - Never Gonna Give You Up",
    "artist": "Rick Astley",
    "duration": 212,
    "thumbnail": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
    "estimatedSize": {
      "mp3": 8704000,
      "m4a": 6963200
    }
  }
}
```

### Direct Download (Original - Still Available)

**Endpoint:** `POST /api/v1/download`

**Rate Limit:** 1 request/minute

**MP3 Download:**
```bash
curl -X POST http://localhost:8000/api/v1/download \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "format": "mp3"
  }' \
  --output audio.mp3
```

**M4A Download:**
```bash
curl -X POST http://localhost:8000/api/v1/download \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "format": "m4a"
  }' \
  --output audio.m4a
```

The file will be streamed in chunks and saved to the specified output file.

---

### Queue System Endpoints (NEW)

#### Add to Queue

**Endpoint:** `POST /api/v1/downloads/queue`

**Rate Limit:** 20 requests/minute

```bash
curl -X POST http://localhost:8000/api/v1/downloads/queue \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: unique-key-123" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "format": "mp3",
    "priority": "normal"
  }'
```

Response:
```json
{
  "id": 1,
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "format": "mp3",
  "priority": "normal",
  "status": "pending",
  "position": 5,
  "message": "Item added to download queue at position 5"
}
```

**Priority Levels**:
- `high`: Downloads first
- `normal`: Standard priority (default)
- `low`: Downloads last

#### List Queue Items

**Endpoint:** `GET /api/v1/downloads/queue`

**Rate Limit:** 30 requests/minute

```bash
# All items
curl http://localhost:8000/api/v1/downloads/queue

# Filter by status
curl http://localhost:8000/api/v1/downloads/queue?status=pending

# Pagination
curl http://localhost:8000/api/v1/downloads/queue?limit=50&offset=0
```

#### Get Queue Item Status

**Endpoint:** `GET /api/v1/downloads/queue/{id}`

**Rate Limit:** 60 requests/minute

```bash
curl http://localhost:8000/api/v1/downloads/queue/1
```

Response includes progress (0-100%):
```json
{
  "id": 1,
  "status": "downloading",
  "progress": 45,
  "title": "Never Gonna Give You Up",
  "artist": "Rick Astley",
  ...
}
```

#### Update Priority

**Endpoint:** `PUT /api/v1/downloads/queue/{id}/priority`

```bash
curl -X PUT http://localhost:8000/api/v1/downloads/queue/1/priority \
  -H "Content-Type: application/json" \
  -d '{"priority": "high"}'
```

#### Pause/Resume

```bash
# Pause
curl -X POST http://localhost:8000/api/v1/downloads/queue/1/pause

# Resume
curl -X POST http://localhost:8000/api/v1/downloads/queue/1/resume
```

#### Remove from Queue

```bash
curl -X DELETE http://localhost:8000/api/v1/downloads/queue/1
```

**For complete queue API documentation, see [QUEUE_API_DOCUMENTATION.md](QUEUE_API_DOCUMENTATION.md)**

**For queue quick start guide, see [QUEUE_QUICK_START.md](QUEUE_QUICK_START.md)**

---

## Error Handling

The API returns structured error responses:

```json
{
  "error": "INVALID_URL",
  "code": "INVALID_URL",
  "message": "URL do YouTube inválida"
}
```

**Error Codes:**
- `INVALID_URL` (400): Invalid YouTube URL
- `VIDEO_UNAVAILABLE` (404): Video not found or private
- `DOWNLOAD_FAILED` (500): Download failed
- `CONVERSION_FAILED` (500): Audio conversion failed (check ffmpeg)
- `NETWORK_ERROR` (503): Network connection issue
- `SERVER_ERROR` (500): Unexpected server error
- `ITEM_NOT_FOUND` (404): Queue item not found
- `CANNOT_CHANGE_PRIORITY` (400): Cannot change priority (not pending)
- `MAX_RETRIES_REACHED` (400): Download failed after max retries

## Docker Usage

### Basic Commands

```bash
# Start the backend
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the backend
docker-compose down

# Rebuild after code changes
docker-compose build
docker-compose up -d
```

### Testing Docker Setup

Run the automated test script:

```bash
chmod +x test-docker.sh
./test-docker.sh
```

This will:
- Build the Docker image
- Start the container
- Run health checks
- Test API endpoints
- Verify ffmpeg and yt-dlp installation
- Display container stats

For complete Docker documentation, see **[DOCKER.md](DOCKER.md)**

## Testing Workflow

### 1. Start the Server

**Using Docker (Recommended):**
```bash
docker-compose up -d
```

**Using Python:**
```bash
python main.py
```

### 2. Check Health
```bash
curl http://localhost:8000/health
```

### 3. Test Queue System (NEW)
```bash
# Add to queue
curl -X POST http://localhost:8000/api/v1/downloads/queue \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "format": "mp3"}'

# Check status
curl http://localhost:8000/api/v1/downloads/queue/1

# List queue
curl http://localhost:8000/api/v1/downloads/queue
```

### 4. Test Direct Download
```bash
curl -X POST http://localhost:8000/api/v1/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "format": "mp3"}' \
  --output test.mp3
```

### 5. Verify Downloaded File
```bash
# Check file exists and has content
ls -lh test.mp3

# Play the audio (macOS)
afplay test.mp3
```

## iOS Simulator Integration

The backend is configured to accept requests from iOS Simulator:

1. **Start Backend:** `docker-compose up -d` or `python main.py`
2. **iOS App Base URL:** `http://localhost:8000`
3. **CORS is pre-configured** for localhost connections

### Using the Queue System from iOS

```swift
// Add to queue
let queueItem = try await api.addToQueue(
    url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    format: .mp3,
    priority: .normal
)

// Poll progress
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
    let status = try await api.getQueueItem(id: queueItem.id)
    print("Progress: \(status.progress)%")
    
    if status.status == "completed" {
        timer.invalidate()
        // Download file or update UI
    }
}
```

## Project Structure

```
backend/
├── main.py                      # FastAPI app entry point
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Docker image definition
├── docker-compose.yml           # Docker Compose configuration
├── .dockerignore               # Docker build exclusions
├── DOCKER.md                   # Docker documentation
├── QUEUE_API_DOCUMENTATION.md  # Queue API reference (NEW)
├── QUEUE_QUICK_START.md        # Queue quick start guide (NEW)
├── QUEUE_IMPLEMENTATION_REPORT.md  # Implementation details (NEW)
├── test-docker.sh              # Docker test script
├── .env                        # Environment variables
├── .env.example                # Environment template
├── .gitignore                  # Git ignore rules
├── app/
│   ├── __init__.py
│   ├── core/
│   │   ├── config.py           # Settings management
│   │   ├── errors.py           # Custom exceptions
│   │   └── database.py         # Database configuration (NEW)
│   ├── models/
│   │   ├── schemas.py          # Pydantic models
│   │   ├── queue_models.py     # Queue database models (NEW)
│   │   └── queue_schemas.py    # Queue API schemas (NEW)
│   ├── services/
│   │   ├── ytdlp_service.py    # yt-dlp integration
│   │   ├── queue_service.py    # Queue management (NEW)
│   │   └── queue_processor.py  # Background worker (NEW)
│   └── api/
│       └── routes/
│           ├── metadata.py     # Metadata endpoint
│           ├── download.py     # Download endpoint
│           ├── health.py       # Health check
│           └── queue.py        # Queue endpoints (NEW)
├── migrations/                 # Database migrations (NEW)
│   ├── 001_create_queue_table.sql
│   ├── 001_rollback.sql
│   └── README.md
├── tests/                      # Unit tests
│   └── test_queue_api.py       # Queue API tests (NEW)
└── temp/                       # Temporary download files (Docker volume)
```

## Development

### View API Documentation

When running in debug mode, interactive docs are available:

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

You'll see all endpoints including the new queue system.

### Run Tests

```bash
# Install pytest
pip install pytest

# Run all tests
pytest tests/ -v

# Run queue tests only
pytest tests/test_queue_api.py -v
```

### Database

Queue data is stored in SQLite:
- **Location**: `/tmp/music_downloader/database/queue.db`
- **Mode**: WAL (Write-Ahead Logging) for better concurrency
- **Auto-cleanup**: Completed items older than 7 days are removed

**Inspect database**:
```bash
sqlite3 /tmp/music_downloader/database/queue.db

# View schema
.schema download_queue

# Count items by status
SELECT status, COUNT(*) FROM download_queue GROUP BY status;

# Exit
.quit
```

### Logs

**Docker:**
```bash
docker-compose logs -f
```

**Local:**
Logs are printed to stdout with format:
```
2025-11-15 10:30:00 - app.services.queue_processor - INFO - Processing queue item 1
```

## Deployment Options

### Option 1: Docker Deployment (Recommended)

The Docker setup is production-ready and can be deployed to:
- AWS ECS/Fargate
- Google Cloud Run
- Azure Container Instances
- Any Docker-compatible platform

See **[DOCKER.md](DOCKER.md)** for production deployment notes.

### Option 2: Traditional Deployment (Render.com, etc.)

For traditional platform deployment:

1. Update `CORS_ORIGINS` to include production iOS app URLs
2. Set `DEBUG=False`
3. Configure persistent storage for temp files and database
4. Add production logging/monitoring
5. Set up environment variables in platform dashboard

## Rate Limits

| Endpoint | Rate Limit |
|----------|------------|
| Metadata | 10/min |
| Direct Download | 1/min |
| Add to Queue | 20/min |
| List Queue | 30/min |
| Get Queue Item | 60/min |
| Queue Operations | 10/min |

Rate limit headers are included in responses:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`

## Queue System Features

### Concurrent Downloads
- Maximum 3 simultaneous downloads
- Background processor monitors queue every 2 seconds
- Priority-based processing (high → normal → low)

### Auto-Retry
- Failed downloads automatically retry
- Maximum 3 retry attempts per item
- Exponential backoff between retries

### Progress Tracking
- Real-time progress updates (0-100%)
- Poll GET endpoint to check status
- Status transitions: pending → downloading → completed/failed

### Idempotency
- Use `Idempotency-Key` header to prevent duplicates
- Same key returns existing queue item
- Keys valid for 24 hours

**For complete documentation, see:**
- **[QUEUE_API_DOCUMENTATION.md](QUEUE_API_DOCUMENTATION.md)** - Full API reference
- **[QUEUE_QUICK_START.md](QUEUE_QUICK_START.md)** - 5-minute setup guide
- **[QUEUE_IMPLEMENTATION_REPORT.md](QUEUE_IMPLEMENTATION_REPORT.md)** - Technical details

## Troubleshooting

### Queue System Issues

**Queue items stuck in "pending":**
```bash
# Check queue processor is running
docker-compose logs backend | grep "Queue processor started"

# Restart backend
docker-compose restart backend
```

**Database errors:**
```bash
# Reset database (WARNING: deletes all queue data)
rm /tmp/music_downloader/database/queue.db
docker-compose restart backend  # Auto-recreates tables
```

### Docker Issues

**Container won't start:**
```bash
# Check logs
docker-compose logs backend

# Check if port 8000 is in use
lsof -i :8000

# Rebuild without cache
docker-compose build --no-cache
```

**Permission errors:**
```bash
# Fix temp directory permissions
docker-compose exec --user root backend chown -R appuser:appuser /tmp/music_downloader
```

See **[DOCKER.md](DOCKER.md)** for more troubleshooting.

### Local Development Issues

**ffmpeg Not Found:**
```
Error: "CONVERSION_FAILED: Falha na conversão de áudio"
```
**Solution:** Install ffmpeg via homebrew: `brew install ffmpeg`

**Permission Denied on Temp Directory:**
```
Error: Permission denied: '/tmp/music_downloader'
```
**Solution:** Create directory manually: `mkdir -p /tmp/music_downloader`

**Rate Limit Exceeded:**
```
Error: 429 Too Many Requests
```
**Solution:** Wait 60 seconds between download requests, or adjust rate limit in .env

**iOS App Can't Connect:**
1. Verify backend is running: `curl http://localhost:8000/health`
2. Check iOS app is using `http://localhost:8000` (not https)
3. Restart both backend and iOS Simulator
4. If using Docker, check container is running: `docker-compose ps`

## Performance Notes

### Docker Image
- **Size:** ~300-400MB (optimized with multi-stage build)
- **Startup Time:** ~5-10 seconds
- **Memory Usage:** ~150-250MB under normal load
- **Queue Processing:** Additional ~50-100MB per concurrent download

### API Performance
- **Metadata Endpoint:** ~1-3 seconds response time
- **Download Speed:** Limited by YouTube and network bandwidth
- **Concurrent Queue Downloads:** 3 (configurable)
- **Queue Processing Latency:** 2-5 seconds

### Database Performance
- **Storage:** ~1KB per queue item
- **Query Speed:** <1ms for indexed lookups
- **Max Items:** Tested up to 10,000 items

## Security

Docker deployment includes:
- Non-root user (UID 1000)
- Minimal base image (python:3.11-slim)
- No unnecessary system packages
- Health checks for automatic recovery
- Rate limiting to prevent abuse
- Input validation on all endpoints
- SQL injection prevention (SQLAlchemy ORM)
- Idempotency keys for duplicate prevention

## Version History

**v2.0.0** (2025-11-15)
- Added download queue system with priority support
- Background processing with concurrent downloads
- SQLite database for queue persistence
- Auto-retry failed downloads
- Progress tracking and status monitoring
- Pause/resume/cancel queue items
- 8 new API endpoints for queue management

**v1.0.0** (2025-01-15)
- Initial release
- YouTube metadata extraction
- Direct audio download (MP3/M4A)
- Docker support
- Rate limiting

## License

Personal use only.

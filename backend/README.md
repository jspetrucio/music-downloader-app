# Music Downloader API - Backend

FastAPI backend service for downloading and converting YouTube videos to audio formats (MP3/M4A).

## Features

- YouTube video/playlist metadata extraction
- Audio download and conversion (MP3 320kbps, M4A 256kbps)
- Streaming chunked responses (no timeout issues)
- Rate limiting protection
- CORS enabled for iOS app connectivity
- Comprehensive error handling
- Health check endpoint
- **Docker support for easy deployment**

## Tech Stack

- **FastAPI**: Modern async web framework
- **yt-dlp**: YouTube download engine
- **ffmpeg**: Audio conversion
- **slowapi**: Rate limiting
- **pydantic**: Data validation

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
  "version": "1.0.0"
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

### Download Audio

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

## Error Handling

The API returns structured error responses:

```json
{
  "error": "INVALID_URL",
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

### 3. Test Metadata Endpoint
```bash
curl -X POST http://localhost:8000/api/v1/metadata \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

### 4. Test Download Endpoint
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

### Troubleshooting iOS Connection

If iOS app can't connect:
1. Check backend is running: `curl http://localhost:8000/health`
2. Check firewall isn't blocking port 8000
3. For real device testing, use Mac's local IP instead of localhost
4. If using Docker, ensure port 8000 is properly mapped

## Project Structure

```
backend/
├── main.py                 # FastAPI app entry point
├── requirements.txt        # Python dependencies
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── .dockerignore          # Docker build exclusions
├── DOCKER.md              # Docker documentation
├── test-docker.sh         # Docker test script
├── .env                    # Environment variables (create from .env.example)
├── .env.example           # Environment template
├── .gitignore             # Git ignore rules
├── app/
│   ├── __init__.py
│   ├── core/
│   │   ├── config.py      # Settings management
│   │   └── errors.py      # Custom exceptions
│   ├── models/
│   │   └── schemas.py     # Pydantic models
│   ├── services/
│   │   └── ytdlp_service.py  # yt-dlp integration
│   └── api/
│       └── routes/
│           ├── metadata.py   # Metadata endpoint
│           ├── download.py   # Download endpoint
│           └── health.py     # Health check
├── tests/                 # Unit tests (TODO)
└── temp/                  # Temporary download files (Docker volume)
```

## Development

### View API Documentation

When running in debug mode, interactive docs are available:

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

### Logs

**Docker:**
```bash
docker-compose logs -f
```

**Local:**
Logs are printed to stdout with format:
```
2025-01-15 10:30:00 - app.services.ytdlp_service - INFO - Fetching metadata for URL: ...
```

### Debugging

**Docker:**
```bash
# Execute shell in container
docker-compose exec backend /bin/bash

# Check Python packages
docker-compose exec backend pip list

# Test yt-dlp
docker-compose exec backend yt-dlp --version

# Test ffmpeg
docker-compose exec backend ffmpeg -version
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
3. Configure persistent storage for temp files
4. Add production logging/monitoring
5. Set up environment variables in platform dashboard

## Rate Limits

- **Metadata:** 10 requests/minute per IP
- **Download:** 1 request/minute per IP

Rate limit headers are included in responses:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`

## Troubleshooting

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
**Solution:** Wait 60 seconds between download requests, or adjust `DOWNLOAD_RATE_LIMIT` in .env

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

### API Performance
- **Metadata Endpoint:** ~1-3 seconds response time
- **Download Speed:** Limited by YouTube and network bandwidth
- **Concurrent Requests:** Supports multiple simultaneous downloads

## Security

Docker deployment includes:
- Non-root user (UID 1000)
- Minimal base image (python:3.11-slim)
- No unnecessary system packages
- Health checks for automatic recovery
- Rate limiting to prevent abuse

## License

Personal use only.

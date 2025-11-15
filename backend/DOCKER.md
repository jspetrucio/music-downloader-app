# Docker Deployment Guide - Music Downloader Backend

This guide covers running the FastAPI backend using Docker for both development and production environments.

## Quick Start

### Prerequisites
- Docker Engine 20.10+ or Docker Desktop
- Docker Compose V2 (included with Docker Desktop)
- 2GB free disk space

### 1. Initial Setup

```bash
cd /Users/josdasil/Documents/App-music/backend

# Create .env file from example
cp .env.example .env

# Edit .env with your configuration (if needed)
nano .env
```

### 2. Build and Run

```bash
# Build the Docker image
docker-compose build

# Start the container in detached mode
docker-compose up -d

# View logs
docker-compose logs -f
```

### 3. Verify It's Working

```bash
# Check health endpoint
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","timestamp":"...","version":"1.0.0"}

# Test metadata endpoint (replace with a real YouTube URL)
curl -X POST http://localhost:8000/api/v1/metadata \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

## Docker Commands Reference

### Building

```bash
# Build image
docker-compose build

# Build without cache (clean build)
docker-compose build --no-cache

# Build with specific Dockerfile
docker build -t music-downloader-backend:latest .
```

### Running

```bash
# Start services
docker-compose up -d

# Start with logs visible
docker-compose up

# Start specific service
docker-compose up -d backend

# Restart services
docker-compose restart

# Stop services
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers + volumes
docker-compose down -v
```

### Monitoring

```bash
# View logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f backend

# View last 100 lines
docker-compose logs --tail=100 backend

# Check container status
docker-compose ps

# Check resource usage
docker stats music-downloader-backend

# Inspect container
docker inspect music-downloader-backend
```

### Debugging

```bash
# Execute shell in running container
docker-compose exec backend /bin/bash

# Execute as root (for debugging permissions)
docker-compose exec --user root backend /bin/bash

# Run one-off command
docker-compose exec backend python --version

# Check environment variables
docker-compose exec backend env

# Test yt-dlp
docker-compose exec backend yt-dlp --version

# Test ffmpeg
docker-compose exec backend ffmpeg -version
```

### Cleanup

```bash
# Remove stopped containers
docker-compose rm

# Remove unused images
docker image prune

# Remove all unused Docker resources
docker system prune -a

# Remove specific image
docker rmi music-downloader-backend:latest
```

## Environment Variables

Configure in `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server host (use 0.0.0.0 in Docker) |
| `PORT` | `8000` | Server port |
| `DEBUG` | `False` | Enable debug mode (True/False) |
| `CORS_ORIGINS` | `http://localhost:*` | Allowed CORS origins (comma-separated) |
| `METADATA_RATE_LIMIT` | `10/minute` | Rate limit for metadata endpoint |
| `DOWNLOAD_RATE_LIMIT` | `1/minute` | Rate limit for download endpoint |
| `MAX_FILE_SIZE_MB` | `50` | Maximum file size in MB |
| `TEMP_DIR` | `/tmp/music_downloader` | Temporary file directory |

### Example Production .env

```bash
HOST=0.0.0.0
PORT=8000
DEBUG=False
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
METADATA_RATE_LIMIT=20/minute
DOWNLOAD_RATE_LIMIT=2/minute
MAX_FILE_SIZE_MB=100
TEMP_DIR=/tmp/music_downloader
```

## Volume Management

The container uses volumes for persistent data:

### Temporary Files Volume
```bash
# Location: ./temp (host) → /tmp/music_downloader (container)

# List contents
docker-compose exec backend ls -la /tmp/music_downloader

# Clean up temp files
rm -rf ./temp/*

# Or from within container
docker-compose exec backend rm -rf /tmp/music_downloader/*
```

### Development Mode (Code Hot-Reload)

Uncomment in `docker-compose.yml`:
```yaml
volumes:
  - ./app:/app/app:ro  # Mount source code
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

## Connecting from iOS Simulator

The iOS app should connect to `http://localhost:8000` from the Mac host.

**Important:** The container exposes port 8000 to the host, so:
- Mac host: `http://localhost:8000` ✓
- iOS Simulator: `http://localhost:8000` ✓
- iOS Physical device: Use Mac's IP address `http://192.168.x.x:8000`

### Find Your Mac's IP Address
```bash
# macOS
ipconfig getifaddr en0  # WiFi
ipconfig getifaddr en1  # Ethernet
```

## Health Checks

The container includes automatic health checks:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' music-downloader-backend

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' music-downloader-backend

# Manual health check
curl http://localhost:8000/health
```

Health states:
- `starting` - Container is starting, waiting for initial check
- `healthy` - All health checks passing
- `unhealthy` - Health checks failing (container will restart)

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs backend

# Common issues:
# 1. Port 8000 already in use
lsof -i :8000
kill -9 <PID>

# 2. Permission issues
docker-compose exec --user root backend chown -R appuser:appuser /tmp/music_downloader
```

### Dependencies Not Found

```bash
# Rebuild without cache
docker-compose build --no-cache

# Check installed packages
docker-compose exec backend pip list
```

### ffmpeg Not Working

```bash
# Verify ffmpeg installation
docker-compose exec backend ffmpeg -version

# Reinstall if needed (exec as root)
docker-compose exec --user root backend apt-get update
docker-compose exec --user root backend apt-get install -y ffmpeg
```

### yt-dlp Errors

```bash
# Update yt-dlp to latest version
docker-compose exec backend pip install --upgrade yt-dlp

# Test directly
docker-compose exec backend yt-dlp --dump-json "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```

### Network Issues

```bash
# Check network connectivity
docker-compose exec backend curl -I https://www.youtube.com

# Verify container IP
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' music-downloader-backend

# Test from host
curl http://localhost:8000/health
```

### High Memory Usage

```bash
# Check resource usage
docker stats music-downloader-backend

# Limit memory in docker-compose.yml:
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### Permission Denied in /tmp

```bash
# Fix permissions
docker-compose exec --user root backend chown -R appuser:appuser /tmp/music_downloader
docker-compose exec --user root backend chmod -R 755 /tmp/music_downloader
```

## Production Deployment

### Security Hardening

1. **Use specific image tags:**
```dockerfile
FROM python:3.11.6-slim  # Instead of python:3.11-slim
```

2. **Scan for vulnerabilities:**
```bash
# Install Trivy
brew install trivy

# Scan image
trivy image music-downloader-backend:latest
```

3. **Set resource limits:**
```yaml
# In docker-compose.yml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
```

4. **Use read-only filesystem where possible:**
```yaml
services:
  backend:
    read_only: true
    tmpfs:
      - /tmp
```

### Logging Configuration

For production, use structured logging:

```yaml
# docker-compose.yml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "production"
```

### Monitoring

```bash
# Export metrics (if Prometheus is available)
curl http://localhost:8000/metrics

# Set up alerts on health check failures
# Docker will auto-restart unhealthy containers
```

### Backup Strategy

```bash
# Backup temp directory
tar -czf backup-$(date +%Y%m%d).tar.gz ./temp

# Restore from backup
tar -xzf backup-20250115.tar.gz
```

### Multi-Environment Setup

Create environment-specific compose files:

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  backend:
    env_file:
      - .env.prod
    restart: always
    deploy:
      replicas: 2
```

Run with:
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Performance Optimization

### Image Size Optimization

Current image size should be ~300-400MB:
```bash
docker images music-downloader-backend
```

Tips to reduce size:
- Multi-stage builds (already implemented) ✓
- Minimal base image (python:3.11-slim) ✓
- Clean apt cache ✓
- No unnecessary dependencies ✓

### Build Cache

Speed up rebuilds:
```bash
# Use BuildKit for better caching
DOCKER_BUILDKIT=1 docker-compose build
```

### Layer Caching

Requirements rarely change, so they're copied before app code for optimal caching.

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build image
        run: |
          cd backend
          docker build -t music-downloader-backend:${{ github.sha }} .
          
      - name: Run tests
        run: |
          docker run --rm music-downloader-backend:${{ github.sha }} pytest
```

## Support

For issues:
1. Check logs: `docker-compose logs -f`
2. Verify health: `curl http://localhost:8000/health`
3. Exec into container: `docker-compose exec backend /bin/bash`
4. Review this documentation

## Image Information

- **Base Image:** python:3.11-slim
- **Architecture:** amd64 (Intel/AMD), arm64 (Apple Silicon)
- **Expected Size:** ~300-400MB
- **User:** appuser (UID 1000, non-root)
- **Exposed Ports:** 8000
- **Health Check:** curl http://localhost:8000/health every 30s

## Updating

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Verify version
curl http://localhost:8000/ | jq .version
```

---

**Last Updated:** 2025-01-15  
**Docker Version:** 24.0+  
**Compose Version:** v2.0+

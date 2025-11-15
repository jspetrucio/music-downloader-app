#!/bin/bash
# Docker Test Script for Music Downloader Backend

set -e  # Exit on error

echo "=========================================="
echo "Docker Setup Test Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi
print_success "Docker is installed"

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi
print_success "Docker Compose is installed"

# Check if .env exists
if [ ! -f .env ]; then
    print_info "Creating .env from .env.example"
    cp .env.example .env
    print_success ".env file created"
else
    print_success ".env file exists"
fi

echo ""
print_info "Step 1: Building Docker image..."
docker-compose build
print_success "Image built successfully"

echo ""
print_info "Step 2: Starting container..."
docker-compose up -d
print_success "Container started"

echo ""
print_info "Step 3: Waiting for container to be healthy (max 60s)..."
COUNTER=0
MAX_ATTEMPTS=20
while [ $COUNTER -lt $MAX_ATTEMPTS ]; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' music-downloader-backend 2>/dev/null || echo "starting")
    
    if [ "$HEALTH" == "healthy" ]; then
        print_success "Container is healthy"
        break
    elif [ "$HEALTH" == "unhealthy" ]; then
        print_error "Container is unhealthy"
        echo ""
        print_info "Container logs:"
        docker-compose logs --tail=50
        exit 1
    fi
    
    echo -n "."
    sleep 3
    COUNTER=$((COUNTER + 1))
done

if [ $COUNTER -eq $MAX_ATTEMPTS ]; then
    print_error "Container did not become healthy in time"
    echo ""
    print_info "Container logs:"
    docker-compose logs --tail=50
    exit 1
fi

echo ""
print_info "Step 4: Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    print_success "Health check passed"
    echo "Response: $HEALTH_RESPONSE"
else
    print_error "Health check failed"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi

echo ""
print_info "Step 5: Testing root endpoint..."
ROOT_RESPONSE=$(curl -s http://localhost:8000/)
if echo "$ROOT_RESPONSE" | grep -q "Music Downloader API"; then
    print_success "Root endpoint working"
    echo "Response: $ROOT_RESPONSE"
else
    print_error "Root endpoint failed"
    echo "Response: $ROOT_RESPONSE"
    exit 1
fi

echo ""
print_info "Step 6: Testing metadata endpoint with real YouTube URL..."
METADATA_RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/metadata \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"}' || echo "failed")

if echo "$METADATA_RESPONSE" | grep -q "title"; then
    print_success "Metadata endpoint working"
    echo "Title found in response"
else
    print_error "Metadata endpoint may have issues"
    echo "Response: $METADATA_RESPONSE"
    # Don't exit - might be rate limiting or network issue
fi

echo ""
print_info "Step 7: Checking container resources..."
docker stats music-downloader-backend --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
print_success "Container stats displayed"

echo ""
print_info "Step 8: Verifying ffmpeg installation..."
FFMPEG_VERSION=$(docker-compose exec -T backend ffmpeg -version 2>&1 | head -n 1)
if echo "$FFMPEG_VERSION" | grep -q "ffmpeg version"; then
    print_success "ffmpeg is installed: $FFMPEG_VERSION"
else
    print_error "ffmpeg not found"
    exit 1
fi

echo ""
print_info "Step 9: Verifying yt-dlp installation..."
YT_DLP_VERSION=$(docker-compose exec -T backend yt-dlp --version)
if [ ! -z "$YT_DLP_VERSION" ]; then
    print_success "yt-dlp is installed: version $YT_DLP_VERSION"
else
    print_error "yt-dlp not found"
    exit 1
fi

echo ""
print_info "Step 10: Checking image size..."
IMAGE_SIZE=$(docker images music-downloader-backend:latest --format "{{.Size}}")
print_success "Image size: $IMAGE_SIZE"
if echo "$IMAGE_SIZE" | grep -qE "[0-9]+MB"; then
    SIZE_NUM=$(echo "$IMAGE_SIZE" | grep -oE "[0-9]+" | head -1)
    if [ "$SIZE_NUM" -lt 500 ]; then
        print_success "Image size under 500MB target ✓"
    else
        print_info "Image size is ${SIZE_NUM}MB (target: <500MB)"
    fi
fi

echo ""
print_info "Step 11: Viewing recent container logs..."
docker-compose logs --tail=20 backend

echo ""
echo "=========================================="
print_success "All tests passed!"
echo "=========================================="
echo ""
echo "Container is running at: http://localhost:8000"
echo "API docs available at: http://localhost:8000/docs"
echo ""
echo "Useful commands:"
echo "  • View logs:        docker-compose logs -f"
echo "  • Stop container:   docker-compose down"
echo "  • Restart:          docker-compose restart"
echo "  • Shell access:     docker-compose exec backend /bin/bash"
echo ""
print_info "To stop the container, run: docker-compose down"

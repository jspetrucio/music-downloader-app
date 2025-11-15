.PHONY: help build up down restart logs shell test clean health

# Default target
help:
	@echo "Music Downloader Backend - Docker Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  make build     - Build Docker image"
	@echo "  make up        - Start containers"
	@echo "  make down      - Stop containers"
	@echo "  make restart   - Restart containers"
	@echo "  make logs      - View logs (follow mode)"
	@echo "  make shell     - Open shell in container"
	@echo "  make test      - Run automated tests"
	@echo "  make health    - Check health endpoint"
	@echo "  make clean     - Remove containers, images, and volumes"
	@echo "  make stats     - Show container resource usage"
	@echo ""

# Build the Docker image
build:
	@echo "Building Docker image..."
	docker-compose build

# Start containers
up:
	@echo "Starting containers..."
	docker-compose up -d
	@echo "Backend is running at http://localhost:8000"

# Stop containers
down:
	@echo "Stopping containers..."
	docker-compose down

# Restart containers
restart:
	@echo "Restarting containers..."
	docker-compose restart

# View logs
logs:
	docker-compose logs -f

# Open shell in container
shell:
	docker-compose exec backend /bin/bash

# Run automated tests
test:
	@echo "Running automated tests..."
	@chmod +x test-docker.sh
	@./test-docker.sh

# Check health endpoint
health:
	@echo "Checking health endpoint..."
	@curl -s http://localhost:8000/health | python3 -m json.tool || echo "Backend not responding"

# Clean up everything
clean:
	@echo "Cleaning up Docker resources..."
	docker-compose down -v
	docker rmi music-downloader-backend:latest || true
	@echo "Cleanup complete"

# Show container stats
stats:
	docker stats music-downloader-backend --no-stream

# Quick rebuild (down + build + up)
rebuild: down build up
	@echo "Rebuild complete!"

# Deploy (production-ready start)
deploy:
	@echo "Deploying in production mode..."
	docker-compose build --no-cache
	docker-compose up -d
	@echo "Waiting for health check..."
	@sleep 10
	@make health

# View last 50 log lines
logs-tail:
	docker-compose logs --tail=50

# Check image size
image-size:
	@docker images music-downloader-backend:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

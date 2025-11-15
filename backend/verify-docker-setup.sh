#!/bin/bash
# Docker Setup Verification Script
# Verifies all Docker files are created correctly without building

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}➜ $1${NC}"
}

print_header() {
    echo -e "${YELLOW}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

ERRORS=0

print_header "Docker Setup Verification"
echo ""

# Check if we're in the right directory
print_info "Verifying working directory..."
if [ ! -f "main.py" ] || [ ! -f "requirements.txt" ]; then
    print_error "Not in backend directory. Please cd to /Users/josdasil/Documents/App-music/backend"
    exit 1
fi
print_success "In correct directory"
echo ""

# Check Dockerfile
print_info "Checking Dockerfile..."
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "Dockerfile exists"
    
    # Verify multi-stage build
    if grep -q "FROM python:3.11-slim as builder" Dockerfile; then
        print_success "  Multi-stage build configured"
    else
        print_error "  Multi-stage build not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify non-root user
    if grep -q "useradd.*appuser" Dockerfile; then
        print_success "  Non-root user configured"
    else
        print_error "  Non-root user not configured"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify ffmpeg
    if grep -q "ffmpeg" Dockerfile; then
        print_success "  ffmpeg installation included"
    else
        print_error "  ffmpeg not in Dockerfile"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify healthcheck
    if grep -q "HEALTHCHECK" Dockerfile; then
        print_success "  Health check configured"
    else
        print_error "  Health check missing"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify port
    if grep -q "EXPOSE 8000" Dockerfile; then
        print_success "  Port 8000 exposed"
    else
        print_error "  Port 8000 not exposed"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Check docker-compose.yml
print_info "Checking docker-compose.yml..."
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "docker-compose.yml exists"
    
    # Verify service name
    if grep -q "backend:" docker-compose.yml; then
        print_success "  Backend service defined"
    else
        print_error "  Backend service not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify port mapping
    if grep -q "8000:8000" docker-compose.yml; then
        print_success "  Port mapping configured (8000:8000)"
    else
        print_error "  Port mapping not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify env_file
    if grep -q "env_file:" docker-compose.yml; then
        print_success "  Environment file configuration found"
    else
        print_error "  env_file configuration missing"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify volumes
    if grep -q "./temp:/tmp/music_downloader" docker-compose.yml; then
        print_success "  Volume mapping configured"
    else
        print_error "  Volume mapping not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify restart policy
    if grep -q "restart:" docker-compose.yml; then
        print_success "  Restart policy configured"
    else
        print_error "  Restart policy missing"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify network
    if grep -q "networks:" docker-compose.yml; then
        print_success "  Custom network configured"
    else
        print_error "  Network configuration missing"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Check .dockerignore
print_info "Checking .dockerignore..."
if [ ! -f ".dockerignore" ]; then
    print_error ".dockerignore not found"
    ERRORS=$((ERRORS + 1))
else
    print_success ".dockerignore exists"
    
    # Verify common ignores
    if grep -q "__pycache__" .dockerignore; then
        print_success "  Python cache ignored"
    else
        print_error "  __pycache__ not in .dockerignore"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "venv/" .dockerignore; then
        print_success "  Virtual environment ignored"
    else
        print_error "  venv/ not in .dockerignore"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q ".env" .dockerignore; then
        print_success "  .env file ignored (security)"
    else
        print_error "  .env not in .dockerignore"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Check DOCKER.md
print_info "Checking DOCKER.md documentation..."
if [ ! -f "DOCKER.md" ]; then
    print_error "DOCKER.md not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "DOCKER.md exists"
    
    # Check content
    if grep -q "Quick Start" DOCKER.md; then
        print_success "  Quick start guide included"
    else
        print_error "  Quick start guide missing"
    fi
    
    if grep -q "Troubleshooting" DOCKER.md; then
        print_success "  Troubleshooting section included"
    else
        print_error "  Troubleshooting section missing"
    fi
    
    if grep -q "Production" DOCKER.md; then
        print_success "  Production deployment notes included"
    else
        print_error "  Production notes missing"
    fi
fi
echo ""

# Check test script
print_info "Checking test-docker.sh..."
if [ ! -f "test-docker.sh" ]; then
    print_error "test-docker.sh not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "test-docker.sh exists"
    
    # Check if executable
    if [ -x "test-docker.sh" ]; then
        print_success "  Script is executable"
    else
        print_info "  Making script executable..."
        chmod +x test-docker.sh
        print_success "  Script is now executable"
    fi
fi
echo ""

# Check Makefile
print_info "Checking Makefile..."
if [ ! -f "Makefile" ]; then
    print_error "Makefile not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "Makefile exists"
    
    # Verify key targets
    if grep -q "^build:" Makefile; then
        print_success "  'make build' target defined"
    fi
    
    if grep -q "^up:" Makefile; then
        print_success "  'make up' target defined"
    fi
    
    if grep -q "^test:" Makefile; then
        print_success "  'make test' target defined"
    fi
    
    if grep -q "^logs:" Makefile; then
        print_success "  'make logs' target defined"
    fi
fi
echo ""

# Check temp directory
print_info "Checking temp directory..."
if [ ! -d "temp" ]; then
    print_error "temp directory not found"
    print_info "Creating temp directory..."
    mkdir -p temp
    print_success "temp directory created"
else
    print_success "temp directory exists"
fi
echo ""

# Check .env file
print_info "Checking environment configuration..."
if [ ! -f ".env.example" ]; then
    print_error ".env.example not found"
    ERRORS=$((ERRORS + 1))
else
    print_success ".env.example exists"
fi

if [ ! -f ".env" ]; then
    print_info ".env not found (will be created from .env.example)"
    if [ -f ".env.example" ]; then
        print_info "Creating .env from .env.example..."
        cp .env.example .env
        print_success ".env created"
    fi
else
    print_success ".env exists"
fi
echo ""

# Check README.md updates
print_info "Checking README.md updates..."
if [ ! -f "README.md" ]; then
    print_error "README.md not found"
    ERRORS=$((ERRORS + 1))
else
    if grep -q "Docker" README.md; then
        print_success "README.md includes Docker documentation"
    else
        print_error "README.md doesn't mention Docker"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Check deployment summary
print_info "Checking deployment summary..."
if [ ! -f "DEPLOYMENT_SUMMARY.md" ]; then
    print_info "DEPLOYMENT_SUMMARY.md not found (optional)"
else
    print_success "DEPLOYMENT_SUMMARY.md exists"
fi
echo ""

# File size check
print_info "Checking file sizes..."
if [ -f "Dockerfile" ]; then
    DOCKERFILE_SIZE=$(wc -c < Dockerfile)
    if [ $DOCKERFILE_SIZE -gt 500 ]; then
        print_success "Dockerfile size: $DOCKERFILE_SIZE bytes"
    else
        print_error "Dockerfile seems too small"
    fi
fi

if [ -f "DOCKER.md" ]; then
    DOCKER_MD_SIZE=$(wc -c < DOCKER.md)
    if [ $DOCKER_MD_SIZE -gt 5000 ]; then
        print_success "DOCKER.md size: $DOCKER_MD_SIZE bytes (comprehensive)"
    else
        print_info "DOCKER.md size: $DOCKER_MD_SIZE bytes"
    fi
fi
echo ""

# Summary
print_header "Verification Summary"
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "All checks passed! Docker setup is complete and ready."
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Build and start: ${BLUE}docker-compose up -d${NC}"
    echo "  2. View logs:       ${BLUE}docker-compose logs -f${NC}"
    echo "  3. Run tests:       ${BLUE}./test-docker.sh${NC}"
    echo "  4. Check health:    ${BLUE}curl http://localhost:8000/health${NC}"
    echo ""
    echo "Or use Makefile shortcuts:"
    echo "  ${BLUE}make up${NC}      - Start container"
    echo "  ${BLUE}make test${NC}    - Run automated tests"
    echo "  ${BLUE}make logs${NC}    - View logs"
    echo "  ${BLUE}make down${NC}    - Stop container"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s). Please review the output above."
    echo ""
    exit 1
fi

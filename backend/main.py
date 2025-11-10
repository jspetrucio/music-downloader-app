"""FastAPI Music Downloader Backend - Main Application"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.errors import MusicDownloaderException
from app.models.schemas import ErrorResponse

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Rate limiter
limiter = Limiter(key_func=get_remote_address)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    logger.info("🚀 Music Downloader API starting...")
    logger.info(f"Environment: {'Development' if settings.DEBUG else 'Production'}")
    logger.info(f"Temp directory: {settings.TEMP_DIR}")
    yield
    logger.info("👋 Music Downloader API shutting down...")


# Create FastAPI app
app = FastAPI(
    title="Music Downloader API",
    description="Backend API for downloading and converting YouTube videos to audio",
    version="1.0.0",
    docs_url="/docs" if settings.DEBUG else None,  # Disable docs in production
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan
)

# Add rate limiter to app state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware - critical for iOS Simulator connectivity
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global exception handler for custom exceptions
@app.exception_handler(MusicDownloaderException)
async def music_downloader_exception_handler(
    request: Request,
    exc: MusicDownloaderException
):
    """Handle all custom music downloader exceptions"""
    logger.error(f"Error processing request: {exc.code} - {exc.message}")
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=exc.__class__.__name__,
            code=exc.code,
            message=exc.message
        ).model_dump()
    )


# Generic exception handler
@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions"""
    logger.exception(f"Unexpected error: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error="ServerError",
            code="SERVER_ERROR",
            message="Erro interno do servidor"
        ).model_dump()
    )


# Import and register routes
from app.api.routes import metadata, download, health

app.include_router(health.router, tags=["Health"])
app.include_router(metadata.router, prefix="/api/v1", tags=["Metadata"])
app.include_router(download.router, prefix="/api/v1", tags=["Download"])


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Music Downloader API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs" if settings.DEBUG else "disabled"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="debug" if settings.DEBUG else "info"
    )

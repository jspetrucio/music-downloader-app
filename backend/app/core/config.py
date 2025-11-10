"""Application configuration"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True

    # CORS
    CORS_ORIGINS: str = "http://localhost:*,http://127.0.0.1:*"

    # Rate Limiting
    METADATA_RATE_LIMIT: str = "20/minute"
    DOWNLOAD_RATE_LIMIT: str = "10/minute"

    # Download Configuration
    MAX_FILE_SIZE_MB: int = 50
    TEMP_DIR: str = "/tmp/music_downloader"

    # YouTube Bypass Configuration
    COOKIE_BROWSER: str = "safari"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()

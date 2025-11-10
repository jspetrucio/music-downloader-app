"""Custom exceptions"""

class MusicDownloaderException(Exception):
    """Base exception for Music Downloader"""
    status_code = 400  # Default status code

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(self.message)


class InvalidURLError(MusicDownloaderException):
    def __init__(self):
        super().__init__("INVALID_URL", "URL do YouTube inválida")


class VideoUnavailableError(MusicDownloaderException):
    def __init__(self):
        super().__init__("VIDEO_UNAVAILABLE", "Vídeo indisponível ou privado")


class DownloadFailedError(MusicDownloaderException):
    def __init__(self, reason: str = ""):
        message = f"Falha ao baixar o áudio"
        if reason:
            message += f": {reason}"
        super().__init__("DOWNLOAD_FAILED", message)


class ConversionFailedError(MusicDownloaderException):
    def __init__(self, format: str):
        super().__init__("CONVERSION_FAILED", f"Falha ao converter para {format}")


class NetworkError(MusicDownloaderException):
    def __init__(self):
        super().__init__("NETWORK_ERROR", "Erro de conexão com YouTube")


class ServerError(MusicDownloaderException):
    def __init__(self, details: str = ""):
        message = "Erro interno do servidor"
        if details:
            message += f": {details}"
        super().__init__("SERVER_ERROR", message)

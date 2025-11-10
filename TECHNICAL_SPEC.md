# 🔧 Technical Specification - Music Downloader App

**Version**: 1.0.0
**Last Updated**: 2025-11-08
**Status**: Draft

---

## 1. System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────┐
│          iOS App (SwiftUI)              │
│  ┌───────────────────────────────────┐  │
│  │   Presentation Layer              │  │
│  │  - Download Tab                   │  │
│  │  - Library Tab                    │  │
│  │  - Playlists Tab                  │  │
│  │  - Player (Mini + Full)           │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Business Logic Layer            │  │
│  │  - DownloadService                │  │
│  │  - AudioPlayerService             │  │
│  │  - StorageManager                 │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Data Layer (SwiftData)          │  │
│  │  - DownloadedSong model           │  │
│  │  - Playlist model                 │  │
│  │  - DownloadHistory model          │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Storage Layer                   │  │
│  │  - Documents/songs/*.m4a          │  │
│  │  - Library/Caches/thumbnails/*.jpg│  │
│  └───────────────────────────────────┘  │
└────────────┬────────────────────────────┘
             │
             │ HTTPS REST API
             │
┌────────────▼────────────────────────────┐
│     Backend (Python FastAPI)            │
│  ┌───────────────────────────────────┐  │
│  │   API Layer                       │  │
│  │  - POST /api/v1/metadata          │  │
│  │  - POST /api/v1/download          │  │
│  │  - GET  /health                   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Service Layer                   │  │
│  │  - YouTubeExtractor (yt-dlp)      │  │
│  │  - AudioConverter (ffmpeg)        │  │
│  │  - RateLimiter (slowapi)          │  │
│  └───────────────────────────────────┘  │
└────────────┬────────────────────────────┘
             │
             │ yt-dlp
             │
┌────────────▼────────────────────────────┐
│          YouTube API                    │
└─────────────────────────────────────────┘
```

---

## 2. iOS App - Data Models (SwiftData)

### 2.1 DownloadedSong

```swift
import SwiftData
import Foundation

@Model
class DownloadedSong {
    // Identifiers
    @Attribute(.unique) var id: UUID
    var youtubeURL: String
    var videoID: String

    // Metadata
    var title: String
    var artist: String?
    var duration: TimeInterval  // seconds
    var thumbnailURL: String?

    // File info
    var fileURL: URL  // file:///Documents/songs/{id}.m4a
    var fileSize: Int64  // bytes
    var format: AudioFormat  // .mp3 or .m4a

    // Playback tracking
    var playCount: Int = 0
    var lastPlayedAt: Date?
    var isFavorite: Bool = false

    // Download tracking
    var downloadedAt: Date
    var downloadsToday: Int = 0  // Reset daily for limit check

    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \Playlist.songs)
    var playlists: [Playlist]?

    init(youtubeURL: String, videoID: String, title: String, fileURL: URL, fileSize: Int64, format: AudioFormat) {
        self.id = UUID()
        self.youtubeURL = youtubeURL
        self.videoID = videoID
        self.title = title
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.format = format
        self.downloadedAt = Date()
    }
}

enum AudioFormat: String, Codable {
    case mp3 = "mp3"
    case m4a = "m4a"

    var contentType: String {
        switch self {
        case .mp3: return "audio/mpeg"
        case .m4a: return "audio/m4a"
        }
    }
}
```

### 2.2 Playlist

```swift
@Model
class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify)
    var songs: [DownloadedSong]

    // Computed properties
    var songCount: Int {
        songs.count
    }

    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }

    var totalSize: Int64 {
        songs.reduce(0) { $0 + $1.fileSize }
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.songs = []
    }
}
```

### 2.3 DownloadHistory

```swift
@Model
class DownloadHistory {
    @Attribute(.unique) var id: UUID
    var youtubeURL: String
    var title: String
    var downloadedAt: Date
    var success: Bool
    var errorMessage: String?
    var fileSize: Int64?
    var format: AudioFormat?

    init(youtubeURL: String, title: String, success: Bool, errorMessage: String? = nil) {
        self.id = UUID()
        self.youtubeURL = youtubeURL
        self.title = title
        self.downloadedAt = Date()
        self.success = success
        self.errorMessage = errorMessage
    }
}
```

---

## 3. iOS App - Services

### 3.1 APIService

```swift
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case rateLimited(retryAfter: Int)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let error):
            return "Erro de rede: \(error.localizedDescription)"
        case .serverError(let message):
            return "Erro do servidor: \(message)"
        case .decodingError:
            return "Erro ao processar resposta"
        case .rateLimited(let seconds):
            return "Muitas requisições. Aguarde \(seconds)s."
        case .timeout:
            return "Tempo esgotado. Tente novamente."
        }
    }
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://[PROJECT-NAME].onrender.com/api/v1"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Metadata Endpoint

    func fetchMetadata(url: String) async throws -> MetadataResponse {
        let endpoint = URL(string: "\(baseURL)/metadata")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw APIError.rateLimited(retryAfter: Int(retryAfter ?? "60") ?? 60)
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Unknown error")
        }

        return try JSONDecoder().decode(MetadataResponse.self, from: data)
    }

    // MARK: - Download Endpoint

    func downloadAudio(url: String, format: AudioFormat, quality: String = "high", progressHandler: @escaping (Double) -> Void) async throws -> DownloadedFile {
        let endpoint = URL(string: "\(baseURL)/download")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body = [
            "url": url,
            "format": format.rawValue,
            "quality": quality
        ]
        request.httpBody = try JSONEncoder().encode(body)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: request) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: APIError.networkError(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let tempURL = tempURL else {
                    continuation.resume(throwing: APIError.serverError("Download failed"))
                    return
                }

                // Extract metadata from headers
                let title = httpResponse.value(forHTTPHeaderField: "X-Song-Title") ?? "Unknown"
                let artist = httpResponse.value(forHTTPHeaderField: "X-Song-Artist")
                let durationString = httpResponse.value(forHTTPHeaderField: "X-Song-Duration")
                let duration = TimeInterval(durationString ?? "0") ?? 0
                let videoID = httpResponse.value(forHTTPHeaderField: "X-Song-VideoID") ?? ""

                let result = DownloadedFile(
                    tempURL: tempURL,
                    title: title,
                    artist: artist,
                    duration: duration,
                    videoID: videoID,
                    format: format
                )

                continuation.resume(returning: result)
            }

            // Track progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress.fractionCompleted)
            }

            task.resume()
        }
    }

    // MARK: - Health Check

    func healthCheck() async throws -> HealthResponse {
        let endpoint = URL(string: "\(baseURL.replacingOccurrences(of: "/api/v1", with: ""))/health")!
        let (data, response) = try await session.data(from: endpoint)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Health check failed")
        }

        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
}

// MARK: - Response Models

struct MetadataResponse: Codable {
    let type: String  // "video" or "playlist"
    let metadata: VideoMetadata?
    let playlistTitle: String?
    let videos: [VideoMetadata]?
}

struct VideoMetadata: Codable {
    let title: String
    let artist: String?
    let duration: Int
    let thumbnailURL: String
    let videoID: String
    let estimatedSize: EstimatedSize
}

struct EstimatedSize: Codable {
    let mp3: Int64
    let m4a: Int64
}

struct ErrorResponse: Codable {
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String]?
    let retryAfter: Int?
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let version: String
    let dependencies: Dependencies
    let metrics: Metrics?
}

struct Dependencies: Codable {
    let ytDlp: String
    let ffmpeg: String

    enum CodingKeys: String, CodingKey {
        case ytDlp = "yt-dlp"
        case ffmpeg
    }
}

struct Metrics: Codable {
    let uptimeSeconds: Int
    let requestsToday: Int
}

struct DownloadedFile {
    let tempURL: URL
    let title: String
    let artist: String?
    let duration: TimeInterval
    let videoID: String
    let format: AudioFormat
}
```

### 3.2 DownloadService

```swift
import Foundation
import SwiftData

class DownloadService: ObservableObject {
    @Published var currentDownload: DownloadProgress?
    @Published var downloadHistory: [DownloadHistory] = []

    private let apiService: APIService
    private let modelContext: ModelContext
    private let storageManager: StorageManager

    init(apiService: APIService = .shared, modelContext: ModelContext, storageManager: StorageManager = .shared) {
        self.apiService = apiService
        self.modelContext = modelContext
        self.storageManager = storageManager
    }

    // MARK: - Download Flow

    func downloadSong(from url: String, format: AudioFormat) async throws -> DownloadedSong {
        // 1. Check daily limit
        try checkDailyLimit()

        // 2. Fetch metadata first
        let metadata = try await apiService.fetchMetadata(url: url)

        guard metadata.type == "video",
              let videoMeta = metadata.metadata else {
            throw DownloadError.invalidURL
        }

        // 3. Check for duplicates
        if try isDuplicate(url: url) {
            throw DownloadError.duplicate
        }

        // 4. Check available storage
        let estimatedSize = format == .mp3 ? videoMeta.estimatedSize.mp3 : videoMeta.estimatedSize.m4a
        try storageManager.checkAvailableSpace(required: estimatedSize)

        // 5. Download with progress tracking
        currentDownload = DownloadProgress(title: videoMeta.title, url: url)

        let downloadedFile = try await apiService.downloadAudio(
            url: url,
            format: format,
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.currentDownload?.progress = progress
                }
            }
        )

        // 6. Save to permanent storage
        let finalURL = try storageManager.saveSong(
            from: downloadedFile.tempURL,
            id: UUID(),
            format: format
        )

        // 7. Create SwiftData model
        let song = DownloadedSong(
            youtubeURL: url,
            videoID: downloadedFile.videoID,
            title: downloadedFile.title,
            fileURL: finalURL,
            fileSize: try storageManager.fileSize(at: finalURL),
            format: format
        )
        song.artist = downloadedFile.artist
        song.duration = downloadedFile.duration
        song.thumbnailURL = videoMeta.thumbnailURL

        modelContext.insert(song)
        try modelContext.save()

        // 8. Record history
        recordHistory(url: url, title: downloadedFile.title, success: true)

        currentDownload = nil
        return song
    }

    // MARK: - Helpers

    private func checkDailyLimit() throws {
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { song in
                song.downloadedAt > Calendar.current.startOfDay(for: Date())
            }
        )

        let todaysDownloads = (try? modelContext.fetch(descriptor)) ?? []

        if todaysDownloads.count >= 20 {
            throw DownloadError.dailyLimitReached
        }
    }

    private func isDuplicate(url: String) throws -> Bool {
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { $0.youtubeURL == url }
        )
        return !(try modelContext.fetch(descriptor)).isEmpty
    }

    private func recordHistory(url: String, title: String, success: Bool, error: String? = nil) {
        let history = DownloadHistory(
            youtubeURL: url,
            title: title,
            success: success,
            errorMessage: error
        )
        modelContext.insert(history)
        try? modelContext.save()
    }
}

struct DownloadProgress {
    let title: String
    let url: String
    var progress: Double = 0.0
}

enum DownloadError: LocalizedError {
    case dailyLimitReached
    case duplicate
    case invalidURL
    case insufficientStorage(required: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "Limite diário de 20 downloads atingido"
        case .duplicate:
            return "Você já baixou esta música"
        case .invalidURL:
            return "URL inválida"
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            return "Espaço insuficiente. Necessário: \(formatter.string(fromByteCount: required)), Disponível: \(formatter.string(fromByteCount: available))"
        }
    }
}
```

### 3.3 StorageManager

```swift
import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default

    private var songsDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("songs")
    }

    private var thumbnailsDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("thumbnails")
    }

    init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: songsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Storage Operations

    func saveSong(from tempURL: URL, id: UUID, format: AudioFormat) throws -> URL {
        let destination = songsDirectory.appendingPathComponent("\(id.uuidString).\(format.rawValue)")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
        return destination
    }

    func deleteSong(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    // MARK: - Storage Info

    func availableSpace() throws -> Int64 {
        let values = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        return values[.systemFreeSize] as? Int64 ?? 0
    }

    func totalLibrarySize() throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(at: songsDirectory, includingPropertiesForKeys: [.fileSizeKey])
        return contents.reduce(0) { total, url in
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return total + Int64(size ?? 0)
        }
    }

    func checkAvailableSpace(required: Int64) throws {
        let available = try availableSpace()

        if available < required + 500_000_000 {  // Keep 500MB buffer
            throw DownloadError.insufficientStorage(required: required, available: available)
        }
    }

    // MARK: - Cleanup

    func cleanupOldSongs(olderThan days: Int, excludeFavorites: Bool = true, modelContext: ModelContext) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate { song in
                if excludeFavorites {
                    return (song.lastPlayedAt ?? song.downloadedAt) < cutoffDate && !song.isFavorite
                } else {
                    return (song.lastPlayedAt ?? song.downloadedAt) < cutoffDate
                }
            }
        )

        let oldSongs = try modelContext.fetch(descriptor)

        for song in oldSongs {
            try deleteSong(at: song.fileURL)
            modelContext.delete(song)
        }

        try modelContext.save()
    }

    func clearThumbnailCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}
```

---

## 4. Backend API - Implementation Guide

### 4.1 Project Structure

```
backend/
├── main.py                 # FastAPI app entry point
├── requirements.txt        # Python dependencies
├── .env                    # Environment variables (gitignored)
├── .gitignore
├── models/
│   ├── requests.py         # Pydantic request models
│   └── responses.py        # Pydantic response models
├── services/
│   ├── youtube_extractor.py
│   ├── audio_converter.py
│   └── rate_limiter.py
└── utils/
    ├── errors.py           # Custom exceptions
    └── logger.py           # Structured logging
```

### 4.2 main.py (FastAPI App)

```python
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import logging
from datetime import datetime

from models.requests import MetadataRequest, DownloadRequest
from models.responses import MetadataResponse, HealthResponse, ErrorResponse
from services.youtube_extractor import YouTubeExtractor
from services.audio_converter import AudioConverter
from utils.logger import setup_logger

app = FastAPI(title="YouTube Music Downloader API", version="1.0.0")
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

logger = setup_logger()

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For personal use
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Service instances
youtube_extractor = YouTubeExtractor()
audio_converter = AudioConverter()

# Startup time for metrics
app_start_time = datetime.utcnow()
request_count_today = 0

@app.post("/api/v1/metadata")
@limiter.limit("10/minute")
async def get_metadata(request: Request, body: MetadataRequest):
    """Extract metadata from YouTube URL without downloading."""
    try:
        logger.info("Metadata request", extra={"url": str(body.url)})

        metadata = await youtube_extractor.extract_metadata(str(body.url))

        logger.info("Metadata extracted successfully", extra={
            "url": str(body.url),
            "type": metadata["type"]
        })

        return metadata

    except ValueError as e:
        logger.error("Invalid URL", extra={"url": str(body.url), "error": str(e)})
        raise HTTPException(
            status_code=400,
            detail={
                "error": {
                    "code": "INVALID_URL",
                    "message": str(e),
                    "details": ["URL must be from youtube.com, youtu.be, or music.youtube.com"]
                }
            }
        )
    except Exception as e:
        logger.error("Metadata extraction failed", extra={"url": str(body.url), "error": str(e)})
        raise HTTPException(
            status_code=500,
            detail={
                "error": {
                    "code": "EXTRACTION_FAILED",
                    "message": "Failed to extract metadata",
                    "details": [str(e)]
                }
            }
        )

@app.post("/api/v1/download")
@limiter.limit("1/minute")
async def download_audio(request: Request, body: DownloadRequest):
    """Download and convert YouTube video to audio (streaming)."""
    global request_count_today
    request_count_today += 1

    try:
        logger.info("Download request", extra={
            "url": str(body.url),
            "format": body.format,
            "quality": body.quality
        })

        # Extract metadata first for headers
        metadata = await youtube_extractor.extract_metadata(str(body.url))

        if metadata["type"] != "video":
            raise ValueError("Can only download individual videos, not playlists")

        video_meta = metadata["metadata"]

        # Stream audio conversion
        audio_stream = audio_converter.convert_stream(
            url=str(body.url),
            format=body.format,
            quality=body.quality
        )

        content_type = "audio/mpeg" if body.format == "mp3" else "audio/m4a"
        filename = f"{video_meta['title']}.{body.format}"

        logger.info("Download started", extra={
            "url": str(body.url),
            "title": video_meta["title"]
        })

        return StreamingResponse(
            audio_stream,
            media_type=content_type,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "X-Song-Title": video_meta["title"],
                "X-Song-Artist": video_meta.get("artist", "Unknown"),
                "X-Song-Duration": str(video_meta["duration"]),
                "X-Song-VideoID": video_meta["videoID"],
                "Transfer-Encoding": "chunked"
            }
        )

    except ValueError as e:
        logger.error("Invalid request", extra={"error": str(e)})
        raise HTTPException(status_code=400, detail={
            "error": {
                "code": "INVALID_REQUEST",
                "message": str(e)
            }
        })
    except Exception as e:
        logger.error("Download failed", extra={"url": str(body.url), "error": str(e)})
        raise HTTPException(status_code=500, detail={
            "error": {
                "code": "DOWNLOAD_FAILED",
                "message": "Failed to download and convert audio",
                "details": [str(e)]
            }
        })

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    import subprocess

    # Check yt-dlp version
    try:
        ytdlp_version = subprocess.check_output(["yt-dlp", "--version"]).decode().strip()
    except:
        ytdlp_version = "NOT_INSTALLED"

    # Check ffmpeg version
    try:
        ffmpeg_output = subprocess.check_output(["ffmpeg", "-version"]).decode()
        ffmpeg_version = ffmpeg_output.split("\n")[0].split(" ")[2]
    except:
        ffmpeg_version = "NOT_INSTALLED"

    uptime = (datetime.utcnow() - app_start_time).total_seconds()

    status = "healthy" if ytdlp_version != "NOT_INSTALLED" else "unhealthy"

    return {
        "status": status,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": "1.0.0",
        "dependencies": {
            "yt-dlp": ytdlp_version,
            "ffmpeg": ffmpeg_version
        },
        "metrics": {
            "uptimeSeconds": int(uptime),
            "requestsToday": request_count_today
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

## 5. Deployment Configuration

### 5.1 Render.com (render.yaml)

```yaml
services:
  - type: web
    name: music-downloader-backend
    env: python
    region: oregon
    plan: free
    buildCommand: pip install -r requirements.txt && pip install yt-dlp --upgrade
    startCommand: uvicorn main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: PYTHON_VERSION
        value: 3.11.0
      - key: PORT
        generateValue: true
```

### 5.2 GitHub Actions (Keep-Alive)

```yaml
# .github/workflows/keep-alive.yml
name: Keep Backend Alive
on:
  schedule:
    - cron: '*/10 * * * *'  # Every 10 minutes
  workflow_dispatch:  # Allow manual trigger

jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping health endpoint
        run: |
          curl -f https://[PROJECT-NAME].onrender.com/health || echo "Health check failed"
```

---

## 6. Testing Strategy

### 6.1 Backend Tests

```python
# tests/test_api.py
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] in ["healthy", "unhealthy"]

def test_metadata_valid_url():
    response = client.post("/api/v1/metadata", json={
        "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    })
    assert response.status_code == 200
    assert response.json()["type"] == "video"

def test_metadata_invalid_url():
    response = client.post("/api/v1/metadata", json={
        "url": "https://example.com/not-youtube"
    })
    assert response.status_code == 400

def test_rate_limiting():
    # Make 11 requests rapidly
    for _ in range(11):
        response = client.post("/api/v1/metadata", json={
            "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        })

    # Last request should be rate limited
    assert response.status_code == 429
```

### 6.2 iOS Tests

```swift
import XCTest
@testable import MusicDownloader

class APIServiceTests: XCTestCase {
    var apiService: APIService!

    override func setUp() {
        super.setUp()
        apiService = APIService()
    }

    func testFetchMetadataValidURL() async throws {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let metadata = try await apiService.fetchMetadata(url: url)

        XCTAssertEqual(metadata.type, "video")
        XCTAssertNotNil(metadata.metadata?.title)
    }

    func testFetchMetadataInvalidURL() async {
        let url = "https://example.com/not-youtube"

        do {
            _ = try await apiService.fetchMetadata(url: url)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func testHealthCheck() async throws {
        let health = try await apiService.healthCheck()
        XCTAssertTrue(health.status == "healthy" || health.status == "unhealthy")
    }
}
```

---

## 7. Performance Targets

### 7.1 Backend

| Metric | Target | Measurement |
|--------|--------|-------------|
| `/metadata` latency (p95) | < 2s | Time to extract metadata |
| `/download` time (3min song) | < 30s | End-to-end download + conversion |
| Streaming chunk delay | < 100ms | Time between chunks |
| Memory usage (per request) | < 256MB | Peak RAM during conversion |
| Cold start (Render) | < 30s | First request after hibernation |

### 7.2 iOS App

| Metric | Target | Measurement |
|--------|--------|-------------|
| App launch time | < 2s | Cold start to first frame |
| Library load (1000 songs) | < 1s | SwiftData fetch + render |
| Search response | < 300ms | Filter results on keystroke |
| Playback start (cold) | < 500ms | Tap song → first audio output |
| Storage check | < 100ms | Calculate available space |

---

## 8. Security Checklist

- [ ] API rate limiting configured (1/min for downloads, 10/min for metadata)
- [ ] URL validation (whitelist YouTube domains only)
- [ ] Input sanitization (Pydantic models)
- [ ] HTTPS enforced (iOS ATS configuration)
- [ ] No sensitive data logged (URLs only, no PII)
- [ ] Error messages sanitized (no stack traces to client)
- [ ] CORS configured appropriately
- [ ] Legal disclaimer shown on first app launch

---

## 9. Monitoring & Observability

### 9.1 Backend Logs (JSON format)

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "level": "INFO",
  "event": "download_started",
  "url": "https://youtube.com/watch?v=...",
  "format": "m4a",
  "quality": "high"
}
```

### 9.2 iOS Telemetry (OSLog)

```swift
import OSLog

let logger = Logger(subsystem: "com.app.musicdownloader", category: "downloads")

logger.info("Download started: \(url, privacy: .private)")
logger.error("Download failed: \(error.localizedDescription, privacy: .public)")
```

---

**END OF TECHNICAL SPECIFICATION**

*This document should be updated as implementation progresses.*

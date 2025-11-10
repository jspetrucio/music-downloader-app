# 🎵 Music Downloader App

> Download YouTube videos as high-quality audio files (MP3/M4A) directly to your iPhone.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![Python](https://img.shields.io/badge/Python-3.11+-green.svg)](https://www.python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-teal.svg)](https://fastapi.tiangolo.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📱 Overview

A modern iOS app that downloads YouTube videos and converts them to high-quality audio files. Built with SwiftUI, SwiftData, and a powerful FastAPI backend using yt-dlp.

### ✨ Key Features

- 🎧 **High-Quality Audio**: MP3 (320kbps) or M4A (256kbps AAC)
- 📱 **Native iOS App**: Built with SwiftUI for smooth performance
- 💾 **Offline Playback**: Listen to your music without internet
- 📊 **Smart Management**: Track downloads with 20/day limit
- 🎨 **Beautiful UI**: Clean, minimalist design inspired by Vevo
- ⚡ **Fast Downloads**: Streaming backend with progress tracking
- 🔒 **Privacy First**: All processing local, no data collection
- 📚 **Playlists**: Organize your music collection
- 🎵 **Built-in Player**: Full-featured audio player with controls

## 🚀 Quick Start

### Prerequisites

**Backend:**
- Python 3.11+
- ffmpeg
- pip

**iOS:**
- macOS with Xcode 15+
- iOS 17+ device or Simulator
- CocoaPods (optional)

### Installation

#### 1️⃣ Backend Setup

```bash
# Clone the repository
git clone https://github.com/jspetrucio/music-downloader-app.git
cd music-downloader-app/backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install ffmpeg (macOS)
brew install ffmpeg

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run the server
python main.py
```

The backend will start at `http://0.0.0.0:8000`

#### 2️⃣ iOS App Setup

```bash
# Open the Xcode project
cd ../
open App-music.xcodeproj

# In Xcode:
# 1. Select your development team
# 2. Choose target device (Simulator or real device)
# 3. Build & Run (⌘R)
```

## 📖 Usage

### Downloading Music

1. **Copy YouTube URL**: Copy any YouTube video URL
2. **Paste in App**: Open the app and paste the URL in the Download tab
3. **Fetch Metadata**: Tap "Buscar Informações" to preview the video
4. **Select Format**: Choose MP3 or M4A
5. **Download**: Tap "Baixar Música" and wait for completion
6. **Enjoy**: Find your music in the Library tab

### Playing Music

- Navigate to the **Library** tab to see all downloaded songs
- Tap any song to start playback
- Use the **Mini Player** at the bottom for quick controls
- Tap the Mini Player to expand to **Full Player** with advanced controls

### Managing Playlists

- Go to the **Playlists** tab
- Create new playlists with the "+" button
- Add songs to playlists from the Library
- Organize your music collection

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│          iOS App (SwiftUI)              │
│  ┌───────────────────────────────────┐  │
│  │   Views (Download, Library, etc)  │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   Services (API, Download, etc)   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │   SwiftData Models & Persistence  │  │
│  └───────────────────────────────────┘  │
└────────────┬────────────────────────────┘
             │ HTTP/REST API
┌────────────▼────────────────────────────┐
│     Backend (Python FastAPI)            │
│  ┌───────────────────────────────────┐  │
│  │  Routes (metadata, download)      │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  yt-dlp Service (YouTube)         │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  ffmpeg (Audio Conversion)        │  │
│  └───────────────────────────────────┘  │
└────────────┬────────────────────────────┘
             │
             ▼
        YouTube API
```

## 🛠️ Technology Stack

### iOS App
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Networking**: URLSession
- **Audio Playback**: AVFoundation

### Backend
- **Language**: Python 3.11
- **Framework**: FastAPI
- **YouTube Download**: yt-dlp
- **Audio Processing**: ffmpeg
- **Rate Limiting**: slowapi
- **ASGI Server**: uvicorn

### Infrastructure
- **Version Control**: Git
- **Hosting**: Render.com (planned)
- **CI/CD**: GitHub Actions (planned)

## 📂 Project Structure

```
music-downloader-app/
├── App-music/                  # iOS App (SwiftUI)
│   ├── Models/                 # SwiftData models
│   │   ├── DownloadedSong.swift
│   │   ├── Playlist.swift
│   │   └── AudioFormat.swift
│   ├── Services/               # Business logic
│   │   ├── APIService.swift
│   │   ├── DownloadService.swift
│   │   ├── StorageManager.swift
│   │   └── AudioPlayerService.swift
│   ├── Views/                  # UI components
│   │   ├── DownloadView.swift
│   │   ├── LibraryView.swift
│   │   ├── PlaylistsView.swift
│   │   └── FullPlayerView.swift
│   └── Info.plist             # App configuration
│
├── backend/                    # Python Backend
│   ├── app/
│   │   ├── api/routes/        # API endpoints
│   │   ├── services/          # Business logic
│   │   ├── models/            # Pydantic schemas
│   │   └── core/              # Config & errors
│   ├── main.py                # FastAPI entry point
│   ├── requirements.txt       # Python dependencies
│   └── .env                   # Environment config
│
├── project-documentation/      # Design & specs
│   └── design/mockups/        # HTML mockups
│
├── CHECKPOINT.md              # Project status
├── SOLUTIONS_LOG.md           # Troubleshooting history
├── TECHNICAL_SPEC.md          # Technical documentation
└── README.md                  # This file
```

## 🎯 API Documentation

### Endpoints

#### `GET /health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

#### `POST /api/v1/metadata`
Fetch video metadata from YouTube URL.

**Request:**
```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

**Response:**
```json
{
  "type": "video",
  "metadata": {
    "title": "Rick Astley - Never Gonna Give You Up",
    "artist": "Rick Astley",
    "duration": 213,
    "thumbnail": "https://...",
    "estimatedSize": {
      "mp3": 8520000,
      "m4a": 5680000
    }
  }
}
```

#### `POST /api/v1/download`
Download and convert video to audio format.

**Request:**
```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "format": "mp3"
}
```

**Response:** Streaming audio file (chunked transfer encoding)

### Rate Limits
- **Metadata**: 20 requests/minute
- **Download**: 10 requests/minute

## ⚙️ Configuration

### Backend Environment Variables

Create a `.env` file in the `backend/` directory:

```bash
# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=True

# CORS Origins (comma-separated)
CORS_ORIGINS=http://localhost:*,http://127.0.0.1:*

# Rate Limiting
METADATA_RATE_LIMIT=20/minute
DOWNLOAD_RATE_LIMIT=10/minute

# Download Configuration
MAX_FILE_SIZE_MB=500
TEMP_DIR=/tmp/music_downloader
```

### iOS App Configuration

The app is configured via `Info.plist`:

- **NSAppTransportSecurity**: Allows HTTP connections to localhost
- **Bundle Identifier**: `com.josdasil.App-music`
- **Deployment Target**: iOS 17.0+

## 🐛 Troubleshooting

### Common Issues

#### iOS Can't Connect to Backend

**Problem:** iOS Simulator shows "Connection refused" or timeout errors.

**Solutions:**
1. Ensure backend is running on `0.0.0.0:8000` (not `localhost` or `127.0.0.1`)
2. Check `Info.plist` has `NSAppTransportSecurity` configured
3. Verify `APIService.swift` uses `http://localhost:8000`
4. Clean build folder in Xcode (⌘⇧K)

**Details:** [SOLUTIONS_LOG.md](SOLUTIONS_LOG.md#problema-1-ios-simulator-não-conectava-ao-backend)

#### Timeout on Long Videos (40min+)

**Problem:** Downloads fail after 5 minutes for long videos.

**Solution:** Already fixed in v1.0! Timeouts increased to 30 minutes.

**Technical Details:**
- `timeoutIntervalForRequest`: 120s (2 min per chunk)
- `timeoutIntervalForResource`: 1800s (30 min total)

**Details:** [SOLUTIONS_LOG.md](SOLUTIONS_LOG.md#problema-2-timeout-em-downloads-de-vídeos-longos)

#### YouTube Rate Limiting / 429 Errors

**Problem:** Backend returns HTTP 429 or YouTube blocks downloads.

**Current Mitigation:**
- Using PO token for bypass
- Multiple player clients (`ios`, `android`, `web`)
- Retry logic with exponential backoff (3 attempts)

**If still blocked:**
1. Wait a few hours for rate limit reset
2. Use a VPN to change IP address
3. Add YouTube cookies from browser (see Backend Dev.md)

## 📚 Documentation

- **[CHECKPOINT.md](CHECKPOINT.md)** - Project status and troubleshooting history
- **[SOLUTIONS_LOG.md](SOLUTIONS_LOG.md)** - Detailed solutions documentation
- **[TECHNICAL_SPEC.md](TECHNICAL_SPEC.md)** - Complete technical specifications
- **[Backend Dev.md](Backend%20Dev.md)** - Backend implementation guide
- **[Executive Summary Music App.md](**Executive%20Summary%20Music%20App**.md)** - Product requirements

## 🗺️ Roadmap

### ✅ v1.0 - Core Functionality (Current)
- [x] Backend API with yt-dlp integration
- [x] iOS app with SwiftUI
- [x] Download MP3/M4A
- [x] Basic playback
- [x] SwiftData persistence
- [x] Daily download limits (20/day)

### 🚧 v1.1 - Enhanced Features (Next)
- [ ] Progress heartbeat via Server-Sent Events
- [ ] Better error handling UI
- [ ] Download queue
- [ ] Background downloads
- [ ] Improved player controls

### 🔮 v2.0 - Advanced Features (Future)
- [ ] Streaming progressive (real-time)
- [ ] Playlist import from YouTube
- [ ] Search functionality
- [ ] Lyrics integration
- [ ] iCloud sync
- [ ] macOS app
- [ ] Apple Watch companion

### 🚀 v3.0 - Production Ready (Long-term)
- [ ] Deploy backend to Render.com
- [ ] CI/CD with GitHub Actions
- [ ] Security audit
- [ ] Performance optimization
- [ ] App Store submission
- [ ] User authentication (optional)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc)
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Jose Petrucio** ([@jspetrucio](https://github.com/jspetrucio))

## 🙏 Acknowledgments

- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** - Powerful YouTube downloader
- **[FastAPI](https://fastapi.tiangolo.com)** - Modern Python web framework
- **[FFmpeg](https://ffmpeg.org)** - Audio/video processing
- **[Claude Code](https://claude.com/claude-code)** - AI-powered development assistant

## ⚠️ Disclaimer

This tool is for **personal use only**. Respect YouTube's Terms of Service and copyright laws. Only download content you have the right to download. The authors are not responsible for misuse of this software.

## 📞 Support

- 🐛 **Bug Reports**: [Open an issue](https://github.com/jspetrucio/music-downloader-app/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/jspetrucio/music-downloader-app/discussions)
- 📧 **Email**: jspetrucio@gmail.com

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/jspetrucio">@jspetrucio</a> and <a href="https://claude.com/claude-code">Claude Code</a>
</p>

<p align="center">
  <a href="#-music-downloader-app">Back to top ⬆️</a>
</p>

//
//  AudioPlayerService.swift
//  App-music
//
//  Music Downloader - Audio playback service using AVAudioPlayer
//

import Foundation
import AVFoundation
import SwiftData

@Observable
final class AudioPlayerService: NSObject {
    static let shared = AudioPlayerService()

    // MARK: - Playback State

    var currentSong: DownloadedSong?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0

    // Queue management
    var queue: [DownloadedSong] = []
    var currentQueueIndex: Int = 0
    var isShuffleEnabled = false
    var repeatMode: RepeatMode = .off

    // Audio player
    private var player: AVAudioPlayer?
    private var updateTimer: Timer?

    private override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Playback Controls

    /// Play a song (replaces current queue)
    func play(_ song: DownloadedSong, modelContext: ModelContext? = nil) {
        play(songs: [song], startIndex: 0, modelContext: modelContext)
    }

    /// Play a list of songs (sets queue)
    func play(songs: [DownloadedSong], startIndex: Int = 0, modelContext: ModelContext? = nil) {
        queue = songs
        currentQueueIndex = startIndex

        guard startIndex < queue.count else { return }

        let song = queue[startIndex]
        playSong(song, modelContext: modelContext)
    }

    /// Play a specific song (internal)
    private func playSong(_ song: DownloadedSong, modelContext: ModelContext?) {
        stopUpdateTimer()

        // Check if file exists before attempting to play
        guard song.fileExists else {
            print("❌ File does not exist at path: \(song.localFilePath)")
            print("   Song: \(song.title) by \(song.artist)")
            print("   Downloaded at: \(song.downloadedAt)")
            
            // Try to find the file in the expected directory
            if let recoveredPath = tryRecoverFilePath(for: song) {
                print("✅ Found file at alternative location: \(recoveredPath)")
                // Update the song's file path
                song.localFilePath = recoveredPath
                try? modelContext?.save()
                // Retry with recovered path
                playSong(song, modelContext: modelContext)
                return
            }
            
            print("❌ Could not recover file path for song: \(song.title)")
            return
        }

        let url = URL(fileURLWithPath: song.localFilePath)

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()

            currentSong = song
            isPlaying = true
            duration = player?.duration ?? 0
            currentTime = 0

            // Update play count and last played date
            if let modelContext = modelContext {
                song.playCount += 1
                song.lastPlayedAt = Date()
                try? modelContext.save()
            }

            startUpdateTimer()

        } catch {
            print("❌ Failed to play song: \(error.localizedDescription)")
            print("   File path: \(song.localFilePath)")
            print("   Song: \(song.title) by \(song.artist)")
        }
    }
    
    /// Try to recover file path by searching in the expected directory
    private func tryRecoverFilePath(for song: DownloadedSong) -> String? {
        let storageManager = StorageManager.shared
        let fileManager = FileManager.default
        
        // First, try exact filename match in current directory
        let storedFilename = (song.localFilePath as NSString).lastPathComponent
        let currentDir = storageManager.currentAudioDirectoryPath
        
        if let files = try? fileManager.contentsOfDirectory(atPath: currentDir) {
            for filename in files {
                if filename == storedFilename {
                    let fullPath = (currentDir as NSString).appendingPathComponent(filename)
                    if fileManager.fileExists(atPath: fullPath) {
                        return fullPath
                    }
                }
            }
        }
        
        // If exact match fails, use StorageManager's smart matching
        return storageManager.findFileForSong(
            title: song.title,
            artist: song.artist,
            format: song.format,
            fileSize: song.fileSize,
            downloadedAt: song.downloadedAt
        )
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopUpdateTimer()
    }

    /// Resume playback
    func resume() {
        player?.play()
        isPlaying = true
        startUpdateTimer()
    }

    /// Stop playback
    func stop() {
        player?.stop()
        player = nil
        currentSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopUpdateTimer()
    }

    /// Seek to time
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    /// Set volume (0.0 to 1.0)
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        player?.volume = volume
    }

    // MARK: - Queue Navigation

    /// Play next song in queue
    func playNext(modelContext: ModelContext? = nil) {
        guard !queue.isEmpty else { return }

        switch repeatMode {
        case .off:
            currentQueueIndex += 1
            if currentQueueIndex < queue.count {
                playSong(queue[currentQueueIndex], modelContext: modelContext)
            } else {
                stop()
            }

        case .one:
            // Replay current song
            seek(to: 0)
            player?.play()

        case .all:
            currentQueueIndex = (currentQueueIndex + 1) % queue.count
            playSong(queue[currentQueueIndex], modelContext: modelContext)
        }
    }

    /// Play previous song in queue
    func playPrevious(modelContext: ModelContext? = nil) {
        guard !queue.isEmpty else { return }

        // If more than 3 seconds into song, restart current song
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        currentQueueIndex -= 1
        if currentQueueIndex < 0 {
            currentQueueIndex = queue.count - 1
        }

        playSong(queue[currentQueueIndex], modelContext: modelContext)
    }

    /// Toggle shuffle
    func toggleShuffle() {
        isShuffleEnabled.toggle()

        if isShuffleEnabled {
            // Shuffle queue (preserve current song)
            if let currentSong = currentSong,
               let currentIndex = queue.firstIndex(where: { $0.id == currentSong.id }) {
                var shuffled = queue
                shuffled.remove(at: currentIndex)
                shuffled.shuffle()
                shuffled.insert(currentSong, at: 0)
                queue = shuffled
                currentQueueIndex = 0
            } else {
                queue.shuffle()
            }
        }
    }

    /// Cycle repeat mode (off -> all -> one -> off)
    func toggleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateCurrentTime() {
        currentTime = player?.currentTime ?? 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // Auto-play next song
            playNext()
        }
    }
}

// MARK: - Repeat Mode

enum RepeatMode {
    case off
    case all
    case one

    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var isActive: Bool {
        self != .off
    }
}

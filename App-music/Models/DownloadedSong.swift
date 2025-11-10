//
//  DownloadedSong.swift
//  App-music
//
//  Music Downloader - SwiftData model for downloaded songs
//

import Foundation
import SwiftData

@Model
final class DownloadedSong {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var youtubeURL: String
    var localFilePath: String
    var thumbnailURL: String?
    var duration: TimeInterval
    var fileSize: Int64
    var format: AudioFormat
    var downloadedAt: Date
    var lastPlayedAt: Date?
    var playCount: Int

    /// Relationship to playlists (many-to-many)
    @Relationship(deleteRule: .nullify, inverse: \Playlist.songs)
    var playlists: [Playlist]?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        youtubeURL: String,
        localFilePath: String,
        thumbnailURL: String? = nil,
        duration: TimeInterval,
        fileSize: Int64,
        format: AudioFormat,
        downloadedAt: Date = Date(),
        lastPlayedAt: Date? = nil,
        playCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.youtubeURL = youtubeURL
        self.localFilePath = localFilePath
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.downloadedAt = downloadedAt
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
    }

    /// Formatted duration (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted file size (MB, KB)
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Check if file exists on disk
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: localFilePath)
    }
}

//
//  Playlist.swift
//  App-music
//
//  Music Downloader - SwiftData model for playlists
//

import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    /// Relationship to songs (many-to-many)
    @Relationship(deleteRule: .nullify)
    var songs: [DownloadedSong]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        songs: [DownloadedSong]? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.songs = songs
    }

    /// Number of songs in playlist
    var songCount: Int {
        songs?.count ?? 0
    }

    /// Total duration of all songs in playlist
    var totalDuration: TimeInterval {
        songs?.reduce(0) { $0 + $1.duration } ?? 0
    }

    /// Formatted total duration (HH:MM:SS or MM:SS)
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Add song to playlist
    func addSong(_ song: DownloadedSong) {
        if songs == nil {
            songs = []
        }
        if !(songs?.contains(where: { $0.id == song.id }) ?? false) {
            songs?.append(song)
            updatedAt = Date()
        }
    }

    /// Remove song from playlist
    func removeSong(_ song: DownloadedSong) {
        songs?.removeAll { $0.id == song.id }
        updatedAt = Date()
    }
}

//
//  AudioFormat.swift
//  App-music
//
//  Music Downloader - Audio format enumeration
//

import Foundation

enum AudioFormat: String, Codable, CaseIterable {
    case mp3 = "mp3"
    case m4a = "m4a"

    var displayName: String {
        switch self {
        case .mp3:
            return "MP3 (320 kbps)"
        case .m4a:
            return "M4A (256 kbps AAC)"
        }
    }

    var fileExtension: String {
        return self.rawValue
    }

    var mimeType: String {
        switch self {
        case .mp3:
            return "audio/mpeg"
        case .m4a:
            return "audio/mp4"
        }
    }

    /// Estimated bitrate in kbps
    var bitrate: Int {
        switch self {
        case .mp3:
            return 320
        case .m4a:
            return 256
        }
    }

    /// Estimated bytes per second (for file size calculation)
    var bytesPerSecond: Int {
        switch self {
        case .mp3:
            return 40 * 1024  // 320 kbps ≈ 40 KB/s
        case .m4a:
            return 32 * 1024  // 256 kbps ≈ 32 KB/s
        }
    }
}

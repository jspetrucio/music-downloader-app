//
//  DownloadHistory.swift
//  App-music
//
//  Music Downloader - SwiftData model for tracking daily download limits
//

import Foundation
import SwiftData

@Model
final class DownloadHistory {
    @Attribute(.unique) var id: UUID
    var date: Date  // Stored as start of day (midnight)
    var downloadCount: Int

    init(
        id: UUID = UUID(),
        date: Date,
        downloadCount: Int = 0
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.downloadCount = downloadCount
    }

    /// Check if this history entry is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Maximum downloads allowed per day
    static let maxDownloadsPerDay = 20

    /// Check if daily limit has been reached
    var limitReached: Bool {
        downloadCount >= Self.maxDownloadsPerDay
    }

    /// Remaining downloads for the day
    var remainingDownloads: Int {
        max(0, Self.maxDownloadsPerDay - downloadCount)
    }
}

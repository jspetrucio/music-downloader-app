//
//  DownloadService.swift
//  App-music
//
//  Music Downloader - Download management with daily limits
//

import Foundation
import SwiftData

@Observable
final class DownloadService {
    static let shared = DownloadService()

    private let apiService = APIService.shared
    private let storageManager = StorageManager.shared

    private init() {}

    // MARK: - Download Limit Check

    /// Check if user can download today (under 20 downloads/day limit)
    func canDownloadToday(modelContext: ModelContext) -> Bool {
        let today = getTodayHistory(modelContext: modelContext)
        return !today.limitReached
    }

    /// Get remaining downloads for today
    func remainingDownloadsToday(modelContext: ModelContext) -> Int {
        let today = getTodayHistory(modelContext: modelContext)
        return today.remainingDownloads
    }

    /// Get or create today's download history
    private func getTodayHistory(modelContext: ModelContext) -> DownloadHistory {
        let today = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<DownloadHistory>(
            predicate: #Predicate { $0.date == today }
        )

        if let history = try? modelContext.fetch(descriptor).first {
            return history
        } else {
            // Create new history for today
            let newHistory = DownloadHistory(date: today, downloadCount: 0)
            modelContext.insert(newHistory)
            return newHistory
        }
    }

    /// Increment download count for today
    private func incrementDownloadCount(modelContext: ModelContext) {
        let today = getTodayHistory(modelContext: modelContext)
        today.downloadCount += 1
        try? modelContext.save()
    }

    // MARK: - Download Flow

    /// Complete download flow: fetch metadata, download, save to library
    func downloadSong(
        url: String,
        format: AudioFormat,
        modelContext: ModelContext,
        progress: @escaping (Double) -> Void
    ) async throws -> DownloadedSong {
        // Check daily limit
        guard canDownloadToday(modelContext: modelContext) else {
            throw APIError.dailyLimitReached
        }

        // Step 1: Fetch metadata
        let metadata = try await apiService.fetchMetadata(url: url)

        guard metadata.type == .video else {
            throw APIError.unknown("Playlists não são suportadas nesta versão")
        }

        guard let title = metadata.metadata.title,
              let artist = metadata.metadata.artist,
              let duration = metadata.metadata.duration else {
            throw APIError.unknown("Metadados incompletos")
        }

        // Step 2: Download audio
        let audioData = try await apiService.downloadAudio(
            url: url,
            format: format,
            progress: progress
        )

        // Step 3: Save to disk
        let filename = storageManager.generateFilename(title: title, format: format)
        let filePath = try storageManager.saveAudioFile(data: audioData, filename: filename)

        // Step 4: Create SwiftData model
        let song = DownloadedSong(
            title: title,
            artist: artist,
            youtubeURL: url,
            localFilePath: filePath,
            thumbnailURL: metadata.metadata.thumbnail,
            duration: duration,
            fileSize: Int64(audioData.count),
            format: format
        )

        // Step 5: Save to database
        modelContext.insert(song)
        try modelContext.save()

        // Step 6: Increment download count
        incrementDownloadCount(modelContext: modelContext)

        return song
    }

    // MARK: - Delete Song

    /// Delete song from library and disk
    func deleteSong(_ song: DownloadedSong, modelContext: ModelContext) throws {
        // Delete file from disk
        try storageManager.deleteAudioFile(at: song.localFilePath)

        // Delete from database
        modelContext.delete(song)
        try modelContext.save()
    }
}

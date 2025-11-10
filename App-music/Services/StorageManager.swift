//
//  StorageManager.swift
//  App-music
//
//  Music Downloader - File storage and management
//

import Foundation

@Observable
final class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default

    /// Audio files directory (Documents/MusicDownloads)
    private var audioDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent("MusicDownloads", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: audioURL.path) {
            try? fileManager.createDirectory(at: audioURL, withIntermediateDirectories: true)
        }

        return audioURL
    }

    private init() {}

    // MARK: - Save Audio

    /// Save audio data to disk
    func saveAudioFile(data: Data, filename: String) throws -> String {
        let fileURL = audioDirectory.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return fileURL.path
    }

    /// Generate unique filename for song
    func generateFilename(title: String, format: AudioFormat) -> String {
        // Sanitize title (remove invalid characters)
        let sanitized = title.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
            .prefix(100)  // Limit length

        // Add timestamp to ensure uniqueness
        let timestamp = Int(Date().timeIntervalSince1970)

        return "\(sanitized)_\(timestamp).\(format.fileExtension)"
    }

    // MARK: - Delete Audio

    /// Delete audio file from disk
    func deleteAudioFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try fileManager.removeItem(at: url)
    }

    // MARK: - Storage Statistics

    /// Calculate total storage used by all audio files
    func totalStorageUsed() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(fileSize)
        }
    }

    /// Formatted total storage (MB, GB)
    func formattedStorageUsed() -> String {
        let bytes = totalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Number of audio files
    func audioFileCount() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.count
    }

    // MARK: - Clear Cache

    /// Delete all audio files (for Settings > Clear Cache)
    func clearAllAudioFiles() throws {
        let files = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)

        for fileURL in files {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Check if file exists at path
    func fileExists(at path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    // MARK: - File Path Recovery
    
    /// Get the current audio directory path (for recovery purposes)
    var currentAudioDirectoryPath: String {
        return audioDirectory.path
    }
    
    /// Try to find a file in the audio directory by matching criteria
    func findFileForSong(title: String, artist: String, format: AudioFormat, fileSize: Int64, downloadedAt: Date) -> String? {
        guard let files = try? fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]) else {
            return nil
        }
        
        let expectedExtension = format.fileExtension
        let matchingFormatFiles = files.filter { $0.pathExtension == expectedExtension }
        
        // Match by title in filename
        let sanitizedTitle = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
            .prefix(100)
            .lowercased()
        
        for fileURL in matchingFormatFiles {
            let filename = fileURL.lastPathComponent.lowercased()
            
            // Check if title matches
            if filename.contains(sanitizedTitle) || sanitizedTitle.contains(filename.components(separatedBy: "_").first ?? "") {
                // Verify file size and date
                if let fileSizeValue = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    let sizeDiff = abs(Int64(fileSizeValue) - fileSize)
                    let tolerance = fileSize / 20 // 5% tolerance
                    if sizeDiff <= tolerance {
                        if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
                            let timeDiff = abs(creationDate.timeIntervalSince(downloadedAt))
                            if timeDiff < 3600 { // 1 hour
                                return fileURL.path
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
}

//
//  QueueService.swift
//  App-music
//
//  Download Queue Management Service - Backend integration with real-time polling
//

import Foundation
import SwiftData

@Observable
final class QueueService {
    static let shared = QueueService()
    
    private let baseURL = "http://localhost:8000"

    // URLSession for queue API calls
    private let session: URLSession

    // Storage manager for saving files
    private let storageManager = StorageManager.shared
    
    // Polling state
    var isPolling = false
    private var pollingTask: Task<Void, Never>?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Add to Queue
    
    /// Add item to download queue
    func addToQueue(
        url: String,
        format: AudioFormat,
        priority: QueuePriority = .normal,
        metadata: MetadataResponse?,
        modelContext: ModelContext
    ) async throws -> QueueItem {
        // Create request
        var queueMetadata: QueueAddRequest.QueueMetadata? = nil
        if let meta = metadata?.metadata {
            queueMetadata = QueueAddRequest.QueueMetadata(
                title: meta.title,
                artist: meta.artist,
                thumbnail: meta.thumbnail,
                duration: meta.duration
            )
        }
        
        let request = QueueAddRequest(
            url: url,
            format: format.rawValue,
            priority: priority.rawValue,
            metadata: queueMetadata
        )
        
        // Add to backend
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue")!
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }

        // Accept both 200 OK and 201 Created
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.from(errorResponse: errorResponse)
            } else {
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let decoder = JSONDecoder()
        let queueResponse = try decoder.decode(QueueItemResponse.self, from: data)
        
        // Create local queue item
        let localItem = QueueItem(
            url: url,
            format: format.rawValue,
            priority: priority,
            title: metadata?.metadata.title,
            artist: metadata?.metadata.artist,
            thumbnailURL: metadata?.metadata.thumbnail,
            duration: metadata?.metadata.duration
        )
        
        localItem.backendId = queueResponse.item.id
        localItem.status = queueResponse.item.status
        localItem.position = queueResponse.item.position
        localItem.needsSync = false
        
        modelContext.insert(localItem)
        try modelContext.save()
        
        // Start polling if not already running
        startPolling(modelContext: modelContext)
        
        return localItem
    }
    
    // MARK: - Fetch Queue
    
    /// Fetch all queue items from backend and sync with local database
    func syncQueue(modelContext: ModelContext) async throws {
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue")!

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"

        print("🔄 Sync: Fetching queue from backend...")
        let (data, response) = try await session.data(for: urlRequest)
        print("🔄 Sync: Response received, status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()

        // Debug: print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔄 Sync: Raw response: \(jsonString)")
        }

        let queueResponse = try decoder.decode(QueueListResponse.self, from: data)
        print("🔄 Sync: Decoded \(queueResponse.items.count) items from backend")

        // Get all local items
        let allLocalItems = try modelContext.fetch(FetchDescriptor<QueueItem>())
        print("🔄 Sync: Found \(allLocalItems.count) local items")
        var backendItemIds = Set<String>()
        var itemsToAddToLibrary: [QueueItem] = []

        // Update or create items from backend
        for backendItem in queueResponse.items {
            guard let backendId = backendItem.id else { continue }
            backendItemIds.insert(backendId)

            // Find existing local item
            if let localItem = allLocalItems.first(where: { $0.backendId == backendId }) {
                print("🔄 Sync: Updating item \(backendId): \(localItem.status) -> \(backendItem.status), progress: \(localItem.progress) -> \(backendItem.progress)")

                // Check if item just completed
                let wasNotCompleted = localItem.statusEnum != .completed
                let isNowCompleted = backendItem.status == "completed"

                // Update existing item
                localItem.status = backendItem.status
                localItem.progress = backendItem.progress
                localItem.position = backendItem.position
                localItem.errorMessage = backendItem.errorMessage
                localItem.title = backendItem.title ?? localItem.title
                localItem.artist = backendItem.artist ?? localItem.artist
                localItem.thumbnailURL = backendItem.thumbnail ?? localItem.thumbnailURL
                localItem.needsSync = false

                // Update timestamps if available
                if let startedAt = backendItem.startedAt, localItem.startedAt == nil {
                    localItem.startedAt = ISO8601DateFormatter().date(from: startedAt)
                }
                if let completedAt = backendItem.completedAt, localItem.completedAt == nil {
                    localItem.completedAt = ISO8601DateFormatter().date(from: completedAt)
                }

                // Add to library if just completed
                if wasNotCompleted && isNowCompleted && !localItem.addedToLibrary {
                    print("📚 Item just completed, will add to library after sync")
                    itemsToAddToLibrary.append(localItem)
                }
            } else {
                // Create new local item from backend
                let newItem = QueueItem(
                    url: backendItem.url,
                    format: backendItem.format,
                    priority: QueuePriority(rawValue: backendItem.priority) ?? .normal,
                    title: backendItem.title,
                    artist: backendItem.artist,
                    thumbnailURL: backendItem.thumbnail,
                    duration: backendItem.duration
                )
                newItem.backendId = backendId
                newItem.status = backendItem.status
                newItem.progress = backendItem.progress
                newItem.position = backendItem.position
                newItem.errorMessage = backendItem.errorMessage
                newItem.needsSync = false
                
                modelContext.insert(newItem)
            }
        }
        
        // Remove local items that no longer exist on backend
        for localItem in allLocalItems {
            if let backendId = localItem.backendId, !backendItemIds.contains(backendId) {
                print("🔄 Sync: Deleting item \(backendId) - no longer on backend")
                modelContext.delete(localItem)
            }
        }

        try modelContext.save()
        print("🔄 Sync: ✅ Saved changes to modelContext")

        // Add completed items to library (after save to avoid conflicts)
        if !itemsToAddToLibrary.isEmpty {
            print("📚 Processing \(itemsToAddToLibrary.count) items to add to library...")
            for item in itemsToAddToLibrary {
                do {
                    try await addCompletedItemToLibrary(item: item, modelContext: modelContext)
                } catch {
                    print("❌ Failed to add item \(item.backendId ?? "unknown") to library: \(error)")
                }
            }
        }

        // Backfill: Add old completed items that weren't added to library yet
        print("📚 Backfill: Checking \(allLocalItems.count) local items...")
        let completedNotInLibrary = allLocalItems.filter {
            $0.statusEnum == .completed && !$0.addedToLibrary
        }
        print("📚 Backfill: Found \(completedNotInLibrary.count) completed items not yet in library")

        if !completedNotInLibrary.isEmpty {
            print("📚 Backfill: Starting to add \(completedNotInLibrary.count) items to library...")
            for (index, item) in completedNotInLibrary.enumerated() {
                print("📚 Backfill: [\(index + 1)/\(completedNotInLibrary.count)] Processing '\(item.title ?? "Unknown")'")
                do {
                    try await addCompletedItemToLibrary(item: item, modelContext: modelContext)
                    print("📚 Backfill: [\(index + 1)/\(completedNotInLibrary.count)] ✅ Success")
                } catch {
                    print("❌ Backfill: [\(index + 1)/\(completedNotInLibrary.count)] Failed for item \(item.backendId ?? "unknown"): \(error)")
                }
            }
            print("📚 Backfill: Completed! Processed \(completedNotInLibrary.count) items")
        } else {
            print("📚 Backfill: No items to process - all completed items already in library ✅")
        }
    }
    
    // MARK: - Get Queue Item
    
    /// Fetch single queue item status from backend
    func getQueueItem(id: String) async throws -> QueueItemDTO {
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(id)")!
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        let itemResponse = try decoder.decode(QueueItemResponse.self, from: data)
        return itemResponse.item
    }
    
    // MARK: - Remove from Queue
    
    /// Remove item from queue
    func removeFromQueue(item: QueueItem, modelContext: ModelContext) async throws {
        // Remove from backend first
        if let backendId = item.backendId {
            let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(backendId)")!
            
            var urlRequest = URLRequest(url: endpoint)
            urlRequest.httpMethod = "DELETE"
            
            let (_, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }
            
            if httpResponse.statusCode != 200 {
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Remove locally
        modelContext.delete(item)
        try modelContext.save()
    }
    
    // MARK: - Update Priority
    
    /// Update item priority
    func updatePriority(item: QueueItem, priority: QueuePriority, modelContext: ModelContext) async throws {
        guard let backendId = item.backendId else {
            throw APIError.serverError("Item not synced with backend")
        }
        
        // Update backend
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(backendId)/priority")!
        
        struct PriorityUpdateRequest: Codable {
            let priority: String
        }
        
        let request = PriorityUpdateRequest(priority: priority.rawValue)
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (_, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        // Update locally
        item.priorityEnum = priority
        item.needsSync = false
        try modelContext.save()
    }
    
    // MARK: - Pause/Resume
    
    /// Pause a downloading item
    func pauseItem(item: QueueItem, modelContext: ModelContext) async throws {
        print("⏸️ QueueService: pauseItem called for \(item.backendId ?? "unknown"), status: \(item.status)")
        guard let backendId = item.backendId else {
            print("❌ QueueService: No backendId!")
            throw APIError.serverError("Item not synced with backend")
        }

        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(backendId)/pause")!
        print("⏸️ QueueService: Calling \(endpoint)")
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ QueueService: Invalid response")
            throw APIError.serverError("Invalid response")
        }

        print("⏸️ QueueService: Response status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            print("❌ QueueService: HTTP error \(httpResponse.statusCode)")
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        item.statusEnum = .paused
        try modelContext.save()
        print("⏸️ QueueService: Item paused and saved")
    }
    
    /// Resume a paused item
    func resumeItem(item: QueueItem, modelContext: ModelContext) async throws {
        print("▶️ QueueService: resumeItem called for \(item.backendId ?? "unknown"), status: \(item.status)")
        guard let backendId = item.backendId else {
            print("❌ QueueService: No backendId!")
            throw APIError.serverError("Item not synced with backend")
        }

        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(backendId)/resume")!
        print("▶️ QueueService: Calling \(endpoint)")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ QueueService: Invalid response")
            throw APIError.serverError("Invalid response")
        }

        print("▶️ QueueService: Response status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            print("❌ QueueService: HTTP error \(httpResponse.statusCode)")
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        item.statusEnum = .pending
        try modelContext.save()
        print("▶️ QueueService: Item resumed and saved")
    }
    
    // MARK: - Batch Operations
    
    /// Clear all completed items
    func clearCompleted(modelContext: ModelContext) async throws {
        // Delete completed items locally
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.status == "completed" || $0.status == "failed" }
        )
        
        let completedItems = try modelContext.fetch(descriptor)
        for item in completedItems {
            if let backendId = item.backendId {
                // Try to delete from backend (best effort)
                try? await removeFromBackendQueue(itemId: backendId)
            }
            modelContext.delete(item)
        }
        
        try modelContext.save()
    }
    
    /// Pause all downloading items
    func pauseAll(modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.status == "downloading" }
        )
        
        let downloadingItems = try modelContext.fetch(descriptor)
        for item in downloadingItems {
            try? await pauseItem(item: item, modelContext: modelContext)
        }
    }
    
    /// Resume all paused items
    func resumeAll(modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.status == "paused" }
        )
        
        let pausedItems = try modelContext.fetch(descriptor)
        for item in pausedItems {
            try? await resumeItem(item: item, modelContext: modelContext)
        }
    }
    
    private func removeFromBackendQueue(itemId: String) async throws {
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(itemId)")!
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "DELETE"
        
        let (_, _) = try await session.data(for: urlRequest)
    }
    
    // MARK: - Library Integration

    /// Download completed queue item file and add to library
    private func addCompletedItemToLibrary(item: QueueItem, modelContext: ModelContext) async throws {
        guard let backendId = item.backendId else {
            print("⚠️ Cannot add to library: no backendId")
            return
        }

        guard item.statusEnum == .completed else {
            print("⚠️ Cannot add to library: item not completed (status: \(item.status))")
            return
        }

        guard !item.addedToLibrary else {
            print("ℹ️ Item already added to library, skipping")
            return
        }

        print("📚 Adding completed queue item \(backendId) to library...")

        // Download file from backend
        let endpoint = URL(string: "\(baseURL)/api/v1/downloads/queue/\(backendId)/file")!

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            throw APIError.serverError("Failed to download file: HTTP \(httpResponse.statusCode)")
        }

        print("📚 Downloaded \(data.count) bytes from backend")

        // Generate filename and save to disk
        let title = item.title ?? "Unknown"
        let format = item.formatEnum
        let filename = storageManager.generateFilename(title: title, format: format)
        let filePath = try storageManager.saveAudioFile(data: data, filename: filename)

        print("📚 Saved file to: \(filePath)")

        // Create DownloadedSong entry
        let song = DownloadedSong(
            title: title,
            artist: item.artist ?? "Unknown Artist",
            youtubeURL: item.url,
            localFilePath: filePath,
            thumbnailURL: item.thumbnailURL,
            duration: item.duration ?? 0,
            fileSize: Int64(data.count),
            format: format
        )

        modelContext.insert(song)

        // Mark queue item as added to library
        item.addedToLibrary = true

        try modelContext.save()

        print("📚 ✅ Successfully added '\(title)' to library")
    }

    // MARK: - Real-time Polling
    
    /// Start polling for queue updates (every 2 seconds for active downloads)
    func startPolling(modelContext: ModelContext) {
        guard !isPolling else { return }

        isPolling = true
        pollingTask = Task {
            var emptyPollCount = 0  // Count polls with no active items

            while !Task.isCancelled {
                do {
                    // Check if there are active downloads
                    let descriptor = FetchDescriptor<QueueItem>(
                        predicate: #Predicate {
                            $0.status == "pending" || $0.status == "downloading"
                        }
                    )

                    let activeItems = try modelContext.fetch(descriptor)

                    // Always sync queue status
                    try await syncQueue(modelContext: modelContext)

                    if activeItems.isEmpty {
                        // No active downloads, but continue a few more times to ensure final sync
                        emptyPollCount += 1
                        if emptyPollCount > 5 {  // Poll 5 more times (10 seconds) after completion
                            isPolling = false
                            break
                        }
                    } else {
                        // Reset counter when we have active items
                        emptyPollCount = 0
                    }

                    // Wait 2 seconds before next poll
                    try await Task.sleep(nanoseconds: 2_000_000_000)

                } catch is CancellationError {
                    break
                } catch {
                    // Error during polling, log and wait before retry
                    print("❌ Polling error: \(error)")
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
            isPolling = false
            print("🛑 Polling stopped")
        }
    }
    
    /// Stop polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
    
    /// Get queue statistics
    func getQueueStats(modelContext: ModelContext) throws -> QueueStats {
        let allItems = try modelContext.fetch(FetchDescriptor<QueueItem>())
        
        let activeCount = allItems.filter { !$0.isCompleted }.count
        let completedCount = allItems.filter { $0.statusEnum == .completed }.count
        let failedCount = allItems.filter { $0.statusEnum == .failed }.count
        let downloadingCount = allItems.filter { $0.statusEnum == .downloading }.count
        let pendingCount = allItems.filter { $0.statusEnum == .pending }.count
        
        return QueueStats(
            total: allItems.count,
            active: activeCount,
            completed: completedCount,
            failed: failedCount,
            downloading: downloadingCount,
            pending: pendingCount
        )
    }
}

// MARK: - Queue Statistics

struct QueueStats {
    let total: Int
    let active: Int
    let completed: Int
    let failed: Int
    let downloading: Int
    let pending: Int
}

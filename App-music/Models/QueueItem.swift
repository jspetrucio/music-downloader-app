//
//  QueueItem.swift
//  App-music
//
//  Download Queue Item - SwiftData model for queue persistence
//

import Foundation
import SwiftData

@Model
final class QueueItem {
    // MARK: - Properties
    
    @Attribute(.unique) var id: String
    var url: String
    var format: String  // "mp3" or "m4a"
    var priority: String  // "high", "normal", "low"
    var status: String  // "pending", "downloading", "completed", "failed", "paused"
    
    // Metadata
    var title: String?
    var artist: String?
    var thumbnailURL: String?
    var duration: TimeInterval?
    
    // Progress tracking
    var progress: Double
    var errorMessage: String?
    
    // Timestamps
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    
    // Queue position
    var position: Int
    
    // Backend sync
    var backendId: String?  // ID from backend queue service
    var needsSync: Bool  // True if local changes not synced to backend
    var addedToLibrary: Bool = false  // True if file has been downloaded and added to library
    
    // MARK: - Initialization
    
    init(
        url: String,
        format: String,
        priority: QueuePriority = .normal,
        title: String? = nil,
        artist: String? = nil,
        thumbnailURL: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = UUID().uuidString
        self.url = url
        self.format = format
        self.priority = priority.rawValue
        self.status = QueueItemStatus.pending.rawValue
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.progress = 0.0
        self.errorMessage = nil
        self.createdAt = Date()
        self.startedAt = nil
        self.completedAt = nil
        self.position = 0
        self.backendId = nil
        self.needsSync = true
        // addedToLibrary has default value = false
    }
    
    // MARK: - Computed Properties
    
    var priorityEnum: QueuePriority {
        get { QueuePriority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
    
    var statusEnum: QueueItemStatus {
        get { QueueItemStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
    
    var formatEnum: AudioFormat {
        get { AudioFormat(rawValue: format) ?? .m4a }
        set { format = newValue.rawValue }
    }
    
    var isActive: Bool {
        statusEnum == .downloading || statusEnum == .pending
    }
    
    var isCompleted: Bool {
        statusEnum == .completed || statusEnum == .failed
    }
    
    var canDelete: Bool {
        statusEnum != .downloading
    }
    
    var canPause: Bool {
        statusEnum == .downloading
    }
    
    var canResume: Bool {
        statusEnum == .paused
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var statusColor: String {
        switch statusEnum {
        case .pending: return "secondary"
        case .downloading: return "primary"
        case .completed: return "success"
        case .failed: return "error"
        case .paused: return "warning"
        }
    }
    
    var statusText: String {
        switch statusEnum {
        case .pending: return "Aguardando..."
        case .downloading: return "Baixando \(progressPercentage)%"
        case .completed: return "Concluído"
        case .failed: return errorMessage ?? "Falhou"
        case .paused: return "Pausado"
        }
    }
}

// MARK: - Enums

enum QueuePriority: String, Codable, CaseIterable {
    case high = "high"
    case normal = "normal"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "Alta"
        case .normal: return "Normal"
        case .low: return "Baixa"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }
}

enum QueueItemStatus: String, Codable {
    case pending = "pending"
    case downloading = "downloading"
    case completed = "completed"
    case failed = "failed"
    case paused = "paused"
    
    var displayName: String {
        switch self {
        case .pending: return "Pendente"
        case .downloading: return "Baixando"
        case .completed: return "Concluído"
        case .failed: return "Falhou"
        case .paused: return "Pausado"
        }
    }
}

// MARK: - Backend API Models

struct QueueItemDTO: Codable {
    let id: String?
    let url: String
    let format: String
    let priority: String
    let status: String
    let title: String?
    let artist: String?
    let thumbnail: String?
    let duration: Double?
    let progress: Double
    let errorMessage: String?
    let filePath: String?
    let fileSize: Int?
    let createdAt: String?
    let startedAt: String?
    let completedAt: String?
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case format
        case priority
        case status
        case title
        case artist
        case thumbnail
        case duration
        case progress
        case errorMessage = "error_message"
        case filePath = "file_path"
        case fileSize = "file_size"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case position
    }
}

struct QueueAddRequest: Codable {
    let url: String
    let format: String
    let priority: String
    let metadata: QueueMetadata?
    
    struct QueueMetadata: Codable {
        let title: String?
        let artist: String?
        let thumbnail: String?
        let duration: Double?
    }
}

struct QueueItemResponse: Codable {
    let success: Bool
    let item: QueueItemDTO
}

struct QueueListResponse: Codable {
    let total: Int
    let items: [QueueItemDTO]
    let stats: [String: Int]
}

struct QueueSuccessResponse: Codable {
    let success: Bool
    let message: String
}

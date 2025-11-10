//
//  APIModels.swift
//  App-music
//
//  Music Downloader - API request/response models matching backend
//

import Foundation

// MARK: - Request Models

struct MetadataRequest: Codable {
    let url: String
}

struct DownloadRequest: Codable {
    let url: String
    let format: String  // "mp3" or "m4a"
}

// MARK: - Response Models

struct MetadataResponse: Codable {
    let type: MetadataType
    let metadata: MetadataContent
}

enum MetadataType: String, Codable {
    case video
    case playlist
}

struct MetadataContent: Codable {
    // Video metadata
    let title: String?
    let artist: String?
    let duration: TimeInterval?
    let thumbnail: String?
    let estimatedSize: EstimatedSize?

    // Playlist metadata
    let videoCount: Int?
    let videos: [VideoPreview]?
}

struct EstimatedSize: Codable {
    let mp3: Int64
    let m4a: Int64
}

struct VideoPreview: Codable {
    let title: String
    let url: String
    let duration: TimeInterval
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let code: String
    let message: String
}

// MARK: - API Error Enum

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case serverError(String)
    case videoUnavailable
    case downloadFailed(String)
    case conversionFailed(String)
    case dailyLimitReached
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let message):
            return "Erro de rede: \(message)"
        case .serverError(let message):
            return "Erro do servidor: \(message)"
        case .videoUnavailable:
            return "Vídeo indisponível ou privado"
        case .downloadFailed(let message):
            return "Falha no download: \(message)"
        case .conversionFailed(let format):
            return "Falha ao converter para \(format.uppercased())"
        case .dailyLimitReached:
            return "Limite diário de 20 downloads atingido. Tente novamente amanhã."
        case .unknown(let message):
            return "Erro desconhecido: \(message)"
        }
    }

    static func from(errorResponse: ErrorResponse) -> APIError {
        switch errorResponse.code {
        case "INVALID_URL":
            return .invalidURL
        case "VIDEO_UNAVAILABLE":
            return .videoUnavailable
        case "DOWNLOAD_FAILED":
            return .downloadFailed(errorResponse.message)
        case "CONVERSION_FAILED":
            return .conversionFailed(errorResponse.message)
        case "NETWORK_ERROR":
            return .networkError(errorResponse.message)
        case "SERVER_ERROR":
            return .serverError(errorResponse.message)
        default:
            return .unknown(errorResponse.message)
        }
    }
}

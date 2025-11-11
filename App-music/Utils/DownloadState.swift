import SwiftUI

// MARK: - Download State

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case success(title: String)
    case error(message: String)

    // MARK: - Computed Properties

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    var progress: Double {
        if case .downloading(let progress) = self {
            return progress
        }
        return 0.0
    }

    // MARK: - Alert Content

    var alertTitle: String {
        switch self {
        case .idle, .downloading:
            return ""
        case .success:
            return "Download Concluído"
        case .error:
            return "Erro no Download"
        }
    }

    var alertMessage: String {
        switch self {
        case .idle, .downloading:
            return ""
        case .success(let title):
            return "'\(title)' foi baixada com sucesso e está disponível na sua biblioteca."
        case .error(let message):
            return message
        }
    }

    var alertButtonText: String {
        switch self {
        case .idle, .downloading:
            return ""
        case .success:
            return "OK"
        case .error:
            return "Tentar Novamente"
        }
    }

    var shouldShowAlert: Bool {
        isSuccess || isError
    }

    // MARK: - Status Text

    var statusText: String {
        switch self {
        case .idle:
            return "Aguardando..."
        case .downloading(let progress):
            return "Baixando... \(Int(progress * 100))%"
        case .success:
            return "Download concluído!"
        case .error:
            return "Erro no download"
        }
    }

    var statusColor: Color {
        switch self {
        case .idle:
            return DesignTokens.textSecondary
        case .downloading:
            return DesignTokens.accentPrimary
        case .success:
            return DesignTokens.success
        case .error:
            return DesignTokens.error
        }
    }

    // MARK: - Button State

    var canStartDownload: Bool {
        if case .idle = self {
            return true
        }
        if case .error = self {
            return true
        }
        return false
    }

    var downloadButtonText: String {
        switch self {
        case .idle:
            return "Baixar Música"
        case .downloading:
            return "Baixando..."
        case .success:
            return "Baixar Novamente"
        case .error:
            return "Tentar Novamente"
        }
    }

    var downloadButtonDisabled: Bool {
        isDownloading
    }
}

// MARK: - Download Progress Update

struct DownloadProgressUpdate {
    let progress: Double
    let bytesDownloaded: Int64
    let totalBytes: Int64

    var progressPercentage: String {
        return "\(Int(progress * 100))%"
    }

    var formattedBytesDownloaded: String {
        return ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }

    var formattedTotalBytes: String {
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var progressText: String {
        return "\(formattedBytesDownloaded) / \(formattedTotalBytes)"
    }
}

// MARK: - Download Error Types

enum DownloadError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case fileSystemError
    case decodingError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida. Verifique o link do YouTube."
        case .networkError:
            return "Erro de conexão. Verifique sua internet."
        case .serverError(let code):
            return "Erro do servidor (código \(code)). Tente novamente."
        case .fileSystemError:
            return "Erro ao salvar arquivo. Verifique o espaço disponível."
        case .decodingError:
            return "Erro ao processar resposta do servidor."
        case .unknown(let message):
            return "Erro desconhecido: \(message)"
        }
    }
}

// MARK: - Download Result

enum DownloadResult {
    case success(DownloadedSong)
    case failure(DownloadError)
}

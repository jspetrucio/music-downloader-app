//
//  APIService.swift
//  App-music
//
//  Music Downloader - Backend API communication service
//

import Foundation

@Observable
final class APIService {
    static let shared = APIService()

    // Backend base URL
    // Using localhost to connect to Mac host from iOS Simulator
    private let baseURL = "http://localhost:8000"

    // URLSession configuration
    private let session: URLSession

    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120      // 2 min per chunk
        config.timeoutIntervalForResource = 1800    // 30 min for long videos
        config.waitsForConnectivity = true          // Wait for reconnection if network drops
        self.session = URLSession(configuration: config)
    }

    // MARK: - Metadata

    /// Fetch metadata from YouTube URL
    func fetchMetadata(url: String) async throws -> MetadataResponse {
        let endpoint = URL(string: "\(baseURL)/api/v1/metadata")!

        let request = MetadataRequest(url: url)

        return try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: request,
            responseType: MetadataResponse.self
        )
    }

    // MARK: - Download

    /// Download audio file with progress tracking
    func downloadAudio(
        url: String,
        format: AudioFormat,
        progress: @escaping (Double) -> Void
    ) async throws -> Data {
        let endpoint = URL(string: "\(baseURL)/api/v1/download")!

        let request = DownloadRequest(
            url: url,
            format: format.rawValue
        )

        // Create URLRequest
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        // Download with progress
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: urlRequest) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: APIError.networkError(error.localizedDescription))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: APIError.serverError("Invalid response"))
                    return
                }

                // Check for error responses
                if httpResponse.statusCode != 200 {
                    if let tempURL = tempURL,
                       let errorData = try? Data(contentsOf: tempURL) {
                        let decoder = JSONDecoder()
                        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                            continuation.resume(throwing: APIError.from(errorResponse: errorResponse))
                        } else {
                            continuation.resume(throwing: APIError.serverError("HTTP \(httpResponse.statusCode)"))
                        }
                    } else {
                        continuation.resume(throwing: APIError.serverError("HTTP \(httpResponse.statusCode)"))
                    }
                    return
                }

                guard let tempURL = tempURL else {
                    continuation.resume(throwing: APIError.downloadFailed("No file downloaded"))
                    return
                }

                do {
                    let data = try Data(contentsOf: tempURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: APIError.downloadFailed(error.localizedDescription))
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progressObject, _ in
                DispatchQueue.main.async {
                    progress(progressObject.fractionCompleted)
                }
            }

            task.resume()

            // Keep observation alive
            withExtendedLifetime(observation) {
                // Observation will be deallocated after task completes
            }
        }
    }

    // MARK: - Generic Request Handler

    private func performRequest<R: Decodable, B: Encodable>(
        endpoint: URL,
        method: String,
        body: B,
        responseType: R.Type,
        attempt: Int = 1
    ) async throws -> R {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid response")
            }

            // Check for error responses
            if httpResponse.statusCode != 200 {
                let errorDecoder = JSONDecoder()
                if let errorResponse = try? errorDecoder.decode(ErrorResponse.self, from: data) {
                    throw APIError.from(errorResponse: errorResponse)
                } else {
                    throw APIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }

            // Decode success response
            let decoder = JSONDecoder()
            return try decoder.decode(R.self, from: data)

        } catch {
            // Retry logic with exponential backoff
            if attempt < maxRetries {
                let delay = retryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }

            // Convert URLError to APIError
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    throw APIError.networkError("Sem conexão com a internet")
                case .timedOut:
                    throw APIError.networkError("Tempo esgotado. Tente novamente.")
                default:
                    throw APIError.networkError(urlError.localizedDescription)
                }
            }

            throw error
        }
    }
}

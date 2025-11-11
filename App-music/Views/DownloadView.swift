//
//  DownloadView.swift
//  App-music
//
//  Music Downloader - Download tab view
//

import SwiftUI
import SwiftData

struct DownloadView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var urlInput = ""
    @State private var selectedFormat: AudioFormat = .m4a
    @State private var metadata: MetadataResponse?
    @State private var isLoadingMetadata = false
    @State private var downloadState: DownloadState = .idle
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccessAlert = false
    @State private var successTitle = ""

    private let apiService = APIService.shared
    private let downloadService = DownloadService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Daily limit indicator
                    dailyLimitBanner

                    // URL Input Section
                    urlInputSection

                    // Metadata Preview Card
                    if let metadata = metadata {
                        metadataCard(metadata)
                    }

                    // Download Button
                    if metadata != nil {
                        downloadButton
                    }
                }
                .padding()
            }
            .navigationTitle("Download")
            .downloadBackground()
            .alert("Erro", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Download Concluído", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {
                    resetForm()
                }
            } message: {
                Text("'\(successTitle)' foi baixada com sucesso e está disponível na sua biblioteca.")
            }
        }
    }

    // MARK: - UI Components

    private var dailyLimitBanner: some View {
        let remaining = downloadService.remainingDownloadsToday(modelContext: modelContext)

        return HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.accentColor)

            Text("\(remaining) downloads restantes hoje")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URL do YouTube")
                .font(.headline)

            HStack {
                TextField("Cole a URL aqui", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: urlInput) { _, _ in
                        metadata = nil
                        errorMessage = nil
                    }

                // Paste button
                Button {
                    if let clipboard = UIPasteboard.general.string {
                        urlInput = clipboard
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            // Fetch metadata button
            Button {
                Task { await fetchMetadata() }
            } label: {
                HStack {
                    if isLoadingMetadata {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isLoadingMetadata ? "Carregando..." : "Buscar Informações")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlInput.isEmpty || isLoadingMetadata)
        }
    }

    private func metadataCard(_ metadata: MetadataResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thumbnail
            if let thumbnailURL = metadata.metadata.thumbnail,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                        }
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
            }

            // Title and Artist
            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.metadata.title ?? "Desconhecido")
                    .font(.title3)
                    .fontWeight(.bold)

                Text(metadata.metadata.artist ?? "Artista Desconhecido")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Duration and Size
            if let duration = metadata.metadata.duration,
               let estimatedSize = metadata.metadata.estimatedSize {
                HStack {
                    Label {
                        Text(formatDuration(duration))
                    } icon: {
                        Image(systemName: "clock")
                    }

                    Spacer()

                    Label {
                        Text(formatBytes(selectedFormat == .mp3 ? estimatedSize.mp3 : estimatedSize.m4a))
                    } icon: {
                        Image(systemName: "doc")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            // Format Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Formato de Áudio")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Formato", selection: $selectedFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var downloadButton: some View {
        VStack(spacing: 12) {
            // Progress bar (shown during download)
            if downloadState.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadState.progress)
                        .customProgressStyle()

                    HStack {
                        Text(downloadState.statusText)
                            .font(.caption)
                            .foregroundColor(downloadState.statusColor)

                        Spacer()

                        Text("\(Int(downloadState.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(downloadState.statusColor)
                    }
                }
                .padding(.horizontal)
            }

            // Download button
            Button {
                Task { await downloadSong() }
            } label: {
                HStack {
                    if downloadState.isDownloading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(downloadState.downloadButtonText)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(downloadState.downloadButtonDisabled)
        }
    }

    // MARK: - Actions

    private func fetchMetadata() async {
        guard !urlInput.isEmpty else { return }

        isLoadingMetadata = true
        errorMessage = nil

        do {
            metadata = try await apiService.fetchMetadata(url: urlInput)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoadingMetadata = false
    }

    private func downloadSong() async {
        guard !urlInput.isEmpty else { return }
        guard let songTitle = metadata?.metadata.title else { return }

        downloadState = .downloading(progress: 0)
        errorMessage = nil

        do {
            _ = try await downloadService.downloadSong(
                url: urlInput,
                format: selectedFormat,
                modelContext: modelContext,
                progress: { progress in
                    downloadState = .downloading(progress: progress)
                }
            )

            // Success - show alert
            downloadState = .success(title: songTitle)
            successTitle = songTitle
            showSuccessAlert = true

        } catch let error as APIError {
            downloadState = .error(message: error.localizedDescription)
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            downloadState = .error(message: error.localizedDescription)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func resetForm() {
        urlInput = ""
        metadata = nil
        downloadState = .idle
        successTitle = ""
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DownloadedSong.self, DownloadHistory.self,
        configurations: config
    )

    return DownloadView()
        .modelContainer(container)
}

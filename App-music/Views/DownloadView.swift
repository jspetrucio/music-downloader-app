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
    
    // Query for recently downloaded songs (5 most recent)
    @Query(
        sort: \DownloadedSong.downloadedAt,
        order: .reverse
    ) private var allDownloadedSongs: [DownloadedSong]
    
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
    
    // Get the 5 most recent downloads
    private var recentDownloads: [DownloadedSong] {
        Array(allDownloadedSongs.prefix(5))
    }

    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackgroundView()
                .ignoresSafeArea()

            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.spacingXL) {
                        // Spacer for top padding
                        Spacer()
                            .frame(height: DesignTokens.spacingMD)

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

                        // Recently Downloaded Section
                        recentlyDownloadedSection

                        // Bottom spacer for mini player
                        Spacer()
                            .frame(height: DesignTokens.spacing2XL)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                }
                .navigationTitle("Download")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
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
    }

    // MARK: - UI Components

    private var dailyLimitBanner: some View {
        let remaining = downloadService.remainingDownloadsToday(modelContext: modelContext)

        return VStack(spacing: DesignTokens.spacingXS) {
            Text("\(remaining)")
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)

            Text("downloads remaining today")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingLG
        )
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                TextField("Paste YouTube URL here", text: $urlInput)
                    .font(.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(DesignTokens.backgroundTertiary)
                    .cornerRadius(DesignTokens.cornerRadiusMedium)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                            .stroke(DesignTokens.glassBorder, lineWidth: 1)
                    }
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
                        .foregroundStyle(DesignTokens.textPrimary)
                        .padding()
                        .background(DesignTokens.backgroundTertiary)
                        .cornerRadius(DesignTokens.cornerRadiusMedium)
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                                .stroke(DesignTokens.glassBorder, lineWidth: 1)
                        }
                }
            }

            // Fetch metadata button
            Button {
                Task { await fetchMetadata() }
            } label: {
                HStack(spacing: DesignTokens.spacingXS) {
                    if isLoadingMetadata {
                        ProgressView()
                            .tint(DesignTokens.textPrimary)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(isLoadingMetadata ? "Loading..." : "Fetch Information")
                        .fontWeight(.medium)
                }
                .foregroundStyle(DesignTokens.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .outlineButtonStyle()
            .disabled(urlInput.isEmpty || isLoadingMetadata)
            .opacity(urlInput.isEmpty || isLoadingMetadata ? 0.5 : 1.0)
        }
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingMD
        )
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
                    .foregroundStyle(.white)

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
                    .foregroundStyle(.white)

                Picker("Formato", selection: $selectedFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingMD
        )
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
                HStack(spacing: DesignTokens.spacingXS) {
                    if downloadState.isDownloading {
                        ProgressView()
                            .tint(DesignTokens.textPrimary)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(downloadState.downloadButtonText)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DesignTokens.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .outlineButtonStyle()
            .disabled(downloadState.downloadButtonDisabled)
            .opacity(downloadState.downloadButtonDisabled ? 0.5 : 1.0)
        }
    }
    
    private var recentlyDownloadedSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // Section Header
            Text("Recently Downloaded")
                .font(.system(size: 36, weight: .thin, design: .rounded))
                .foregroundStyle(DesignTokens.textPrimary)

            if recentDownloads.isEmpty {
                // Empty state
                VStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignTokens.textSecondary)

                    Text("No downloads yet")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignTokens.textSecondary)

                    Text("Downloaded songs will appear here")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingXL)
                .minimalistCard(
                    cornerRadius: DesignTokens.cornerRadiusLarge,
                    padding: DesignTokens.spacingLG
                )
            } else {
                // List of recent downloads
                VStack(spacing: DesignTokens.spacingMD) {
                    ForEach(recentDownloads) { song in
                        RecentDownloadRow(song: song)
                    }
                }
            }
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

// MARK: - Recent Download Row Component

struct RecentDownloadRow: View {
    let song: DownloadedSong

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Thumbnail
            if let thumbnailURL = song.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(DesignTokens.backgroundTertiary)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))
            } else {
                // Fallback if no thumbnail
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall)
                    .fill(DesignTokens.backgroundTertiary)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
            }

            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Three-dot menu button
            Button {
                // Non-functional for now
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(.plain)
        }
        .minimalistCard(
            cornerRadius: DesignTokens.cornerRadiusLarge,
            padding: DesignTokens.spacingSM
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DownloadedSong.self, DownloadHistory.self,
        configurations: config
    )
    
    // Add some sample data
    let context = container.mainContext
    let sampleSong = DownloadedSong(
        title: "Sample Song",
        artist: "Sample Artist",
        youtubeURL: "https://youtube.com/watch?v=test",
        localFilePath: "/path/to/file.m4a",
        thumbnailURL: "https://i.ytimg.com/vi/test/maxresdefault.jpg",
        duration: 180,
        fileSize: 3_500_000,
        format: .m4a
    )
    context.insert(sampleSong)

    return DownloadView()
        .modelContainer(container)
}

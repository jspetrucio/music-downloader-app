//
//  LibraryView.swift
//  App-music
//
//  Music Downloader - Library view with search and sorting
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var songs: [DownloadedSong]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .recent
    @State private var songToDelete: DownloadedSong?
    @State private var showDeleteConfirmation = false

    private var filteredSongs: [DownloadedSong] {
        var filtered = songs

        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOption {
        case .recent:
            filtered.sort { $0.downloadedAt > $1.downloadedAt }
        case .title:
            filtered.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .artist:
            filtered.sort { $0.artist.localizedCompare($1.artist) == .orderedAscending }
        }

        return filtered
    }

    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            NavigationStack {
                Group {
                    if songs.isEmpty {
                        emptyState
                    } else {
                        songList
                    }
                }
                .navigationTitle("Biblioteca")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .searchable(text: $searchText, prompt: "Buscar músicas")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
                .confirmationDialog(
                    "Excluir '\(songToDelete?.title ?? "")'?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Excluir", role: .destructive) {
                        if let song = songToDelete {
                            confirmDelete(song)
                        }
                    }
                    Button("Cancelar", role: .cancel) {
                        songToDelete = nil
                    }
                } message: {
                    Text("Esta ação não pode ser desfeita. O arquivo será removido permanentemente do seu dispositivo.")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - UI Components

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.textTertiary)

                Text("Nenhuma música baixada")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Baixe músicas na aba Download")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(DesignTokens.spacingXL)
            .minimalistCard()
            .padding(.horizontal, DesignTokens.spacingMD)
            
            Spacer()
        }
    }

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(filteredSongs) { song in
                    SongRow(song: song)
                        .minimalistCard(padding: DesignTokens.spacingSM)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playSong(song)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                songToDelete = song
                                showDeleteConfirmation = true
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.top, DesignTokens.spacingSM)
            .padding(.bottom, DesignTokens.spacingXL)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Ordenar por", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Label(option.displayName, systemImage: option.iconName)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(DesignTokens.accentPrimary)
        }
    }

    // MARK: - Actions

    private func playSong(_ song: DownloadedSong) {
        AudioPlayerService.shared.play(
            songs: filteredSongs,
            startIndex: filteredSongs.firstIndex(where: { $0.id == song.id }) ?? 0,
            modelContext: modelContext
        )
    }

    private func confirmDelete(_ song: DownloadedSong) {
        do {
            try DownloadService.shared.deleteSong(song, modelContext: modelContext)
            songToDelete = nil
        } catch {
            print("Failed to delete song: \(error)")
            // TODO: Show error alert to user
        }
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: DownloadedSong

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Thumbnail or placeholder
            if let thumbnailURL = song.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        DesignTokens.backgroundTertiary
                        ProgressView()
                            .tint(DesignTokens.accentPrimary)
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(DesignTokens.cornerRadiusMedium)
            } else {
                ZStack {
                    DesignTokens.backgroundTertiary
                    Image(systemName: "music.note")
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(DesignTokens.cornerRadiusMedium)
            }

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(song.formattedDuration, systemImage: "clock")
                    Label(song.formattedFileSize, systemImage: "doc")
                    Label(song.format.rawValue.uppercased(), systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            }

            Spacer()

            // File status indicator
            if !song.fileExists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.warning)
                    .font(.caption)
            }
            
            // Play count badge
            if song.playCount > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(DesignTokens.accentPrimary)
                    Text("\(song.playCount)")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .opacity(song.fileExists ? 1.0 : 0.6)
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case recent = "Recentes"
    case title = "Título"
    case artist = "Artista"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .recent: return "clock"
        case .title: return "textformat"
        case .artist: return "person"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DownloadedSong.self, configurations: config)

    return LibraryView()
        .modelContainer(container)
}

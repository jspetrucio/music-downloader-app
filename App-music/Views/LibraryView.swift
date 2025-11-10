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
        NavigationStack {
            Group {
                if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
            .navigationTitle("Biblioteca")
            .searchable(text: $searchText, prompt: "Buscar músicas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
        }
    }

    // MARK: - UI Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Nenhuma música baixada")
                .font(.title3)
                .fontWeight(.medium)

            Text("Baixe músicas na aba Download")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var songList: some View {
        List {
            ForEach(filteredSongs) { song in
                SongRow(song: song)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playSong(song)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSong(song)
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
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

    private func deleteSong(_ song: DownloadedSong) {
        do {
            try DownloadService.shared.deleteSong(song, modelContext: modelContext)
        } catch {
            print("Failed to delete song: \(error)")
        }
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: DownloadedSong

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            if let thumbnailURL = song.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(song.formattedDuration, systemImage: "clock")
                    Label(song.formattedFileSize, systemImage: "doc")
                    Label(song.format.rawValue.uppercased(), systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // File status indicator
            if !song.fileExists {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help("Arquivo não encontrado")
            }
            
            // Play count badge
            if song.playCount > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("\(song.playCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
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

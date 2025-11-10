//
//  PlaylistDetailView.swift
//  App-music
//
//  Music Downloader - Playlist detail view
//

import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSongs: [DownloadedSong]

    let playlist: Playlist

    @State private var showAddSongs = false

    private var playlistSongs: [DownloadedSong] {
        playlist.songs ?? []
    }

    private var availableSongs: [DownloadedSong] {
        allSongs.filter { song in
            !(playlist.songs?.contains(where: { $0.id == song.id }) ?? false)
        }
    }

    var body: some View {
        Group {
            if playlistSongs.isEmpty {
                emptyState
            } else {
                songList
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddSongs = true
                    } label: {
                        Label("Adicionar Músicas", systemImage: "plus")
                    }

                    if !playlistSongs.isEmpty {
                        Button {
                            playAll()
                        } label: {
                            Label("Tocar Todas", systemImage: "play.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddSongs) {
            addSongsSheet
        }
    }

    // MARK: - UI Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Playlist vazia")
                .font(.title3)
                .fontWeight(.medium)

            Text("Adicione músicas da sua biblioteca")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !availableSongs.isEmpty {
                Button {
                    showAddSongs = true
                } label: {
                    Label("Adicionar Músicas", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var songList: some View {
        List {
            // Playlist header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("\(playlist.songCount) música\(playlist.songCount == 1 ? "" : "s")", systemImage: "music.note")
                        Spacer()
                        Label(playlist.formattedTotalDuration, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        playAll()
                    } label: {
                        Label("Tocar Todas", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 8)
            }

            // Songs
            Section {
                ForEach(playlistSongs) { song in
                    SongRow(song: song)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playSong(song)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeSong(song)
                            } label: {
                                Label("Remover", systemImage: "minus.circle")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
    }

    private var addSongsSheet: some View {
        NavigationStack {
            List {
                if availableSongs.isEmpty {
                    Text("Todas as músicas já estão nesta playlist")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableSongs) { song in
                        Button {
                            addSong(song)
                        } label: {
                            HStack {
                                SongRow(song: song)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Adicionar Músicas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        showAddSongs = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addSong(_ song: DownloadedSong) {
        playlist.addSong(song)
        try? modelContext.save()
    }

    private func removeSong(_ song: DownloadedSong) {
        playlist.removeSong(song)
        try? modelContext.save()
    }

    private func playSong(_ song: DownloadedSong) {
        AudioPlayerService.shared.play(
            songs: playlistSongs,
            startIndex: playlistSongs.firstIndex(where: { $0.id == song.id }) ?? 0,
            modelContext: modelContext
        )
    }

    private func playAll() {
        guard !playlistSongs.isEmpty else { return }
        AudioPlayerService.shared.play(songs: playlistSongs, startIndex: 0, modelContext: modelContext)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Playlist.self, configurations: config)

    let playlist = Playlist(name: "Favoritas")
    container.mainContext.insert(playlist)

    return NavigationStack {
        PlaylistDetailView(playlist: playlist)
            .modelContainer(container)
    }
}

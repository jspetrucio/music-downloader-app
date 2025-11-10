//
//  PlaylistsView.swift
//  App-music
//
//  Music Downloader - Playlists management view
//

import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    emptyState
                } else {
                    playlistList
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nova Playlist", isPresented: $showCreatePlaylist) {
                TextField("Nome da playlist", text: $newPlaylistName)
                Button("Cancelar", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Criar") {
                    createPlaylist()
                }
            }
        }
    }

    // MARK: - UI Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Nenhuma playlist criada")
                .font(.title3)
                .fontWeight(.medium)

            Text("Crie playlists para organizar suas músicas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreatePlaylist = true
            } label: {
                Label("Criar Playlist", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var playlistList: some View {
        List {
            ForEach(playlists) { playlist in
                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                    PlaylistRow(playlist: playlist)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletePlaylist(playlist)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func createPlaylist() {
        guard !newPlaylistName.isEmpty else { return }

        let playlist = Playlist(name: newPlaylistName)
        modelContext.insert(playlist)

        do {
            try modelContext.save()
            newPlaylistName = ""
        } catch {
            print("Failed to create playlist: \(error)")
        }
    }

    private func deletePlaylist(_ playlist: Playlist) {
        modelContext.delete(playlist)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete playlist: \(error)")
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)

                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .fontWeight(.medium)

                if playlist.songCount > 0 {
                    HStack(spacing: 12) {
                        Label("\(playlist.songCount) música\(playlist.songCount == 1 ? "" : "s")", systemImage: "music.note")
                        Label(playlist.formattedTotalDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Vazia")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Playlist.self, configurations: config)

    return PlaylistsView()
        .modelContainer(container)
}

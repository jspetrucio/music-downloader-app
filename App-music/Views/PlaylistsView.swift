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
        ZStack {
            // Animated background
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            NavigationStack {
                Group {
                    if playlists.isEmpty {
                        emptyState
                    } else {
                        playlistList
                    }
                }
                .navigationTitle("Playlists")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreatePlaylist = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.accentPrimary)
                                .font(.title3)
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
        .preferredColorScheme(.dark)
    }

    // MARK: - UI Components

    private var emptyState: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            Spacer()
            
            VStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignTokens.textTertiary)

                Text("Nenhuma playlist criada")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)

                Text("Crie playlists para organizar suas músicas")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    showCreatePlaylist = true
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "plus.circle.fill")
                        Text("Criar Playlist")
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background(
                        LinearGradient(
                            colors: [DesignTokens.accentPrimary, DesignTokens.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DesignTokens.cornerRadiusXL)
                }
                .padding(.top, DesignTokens.spacingSM)
            }
            .padding(DesignTokens.spacingXL)
            .minimalistCard()
            .padding(.horizontal, DesignTokens.spacingMD)
            
            Spacer()
        }
    }

    private var playlistList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingSM) {
                ForEach(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        PlaylistRow(playlist: playlist)
                            .minimalistCard(padding: DesignTokens.spacingSM)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deletePlaylist(playlist)
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
        HStack(spacing: DesignTokens.spacingSM) {
            // Icon with gradient
            ZStack {
                LinearGradient(
                    colors: [
                        DesignTokens.accentPrimary.opacity(0.3),
                        DesignTokens.accentSecondary.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 60, height: 60)
                .cornerRadius(DesignTokens.cornerRadiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                        .stroke(DesignTokens.accentPrimary.opacity(0.5), lineWidth: 1)
                )

                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.accentPrimary)
            }

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.textPrimary)

                if playlist.songCount > 0 {
                    HStack(spacing: 12) {
                        Label("\(playlist.songCount) música\(playlist.songCount == 1 ? "" : "s")", systemImage: "music.note")
                        Label(playlist.formattedTotalDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    Text("Vazia")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Playlist.self, configurations: config)

    return PlaylistsView()
        .modelContainer(container)
}

//
//  MainTabView.swift
//  App-music
//
//  Music Downloader - Main tab navigation
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showFullPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main TabView
            TabView(selection: $selectedTab) {
                DownloadView()
                    .tabItem {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                    }
                    .tag(0)

                LibraryView()
                    .tabItem {
                        Label("Biblioteca", systemImage: "music.note.list")
                    }
                    .tag(1)

                PlaylistsView()
                    .tabItem {
                        Label("Playlists", systemImage: "rectangle.stack.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Ajustes", systemImage: "gear")
                    }
                    .tag(3)
            }
            .tint(Color.accentColor)

            // Mini Player Overlay
            if AudioPlayerService.shared.currentSong != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 49)  // Tab bar height
                    .transition(.move(edge: .bottom))
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(isPresented: $showFullPlayer)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DownloadedSong.self, Playlist.self, DownloadHistory.self,
        configurations: config
    )

    return MainTabView()
        .modelContainer(container)
}

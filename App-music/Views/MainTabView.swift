//
//  MainTabView.swift
//  App-music
//
//  Music Downloader - Main tab navigation
//

import SwiftUI
import SwiftData

// MARK: - Tab Definition

enum Tab: Int, CaseIterable {
    case download = 0
    case library = 1
    case playlists = 2
    case settings = 3

    var title: String {
        switch self {
        case .download: return "Download"
        case .library: return "Biblioteca"
        case .playlists: return "Playlists"
        case .settings: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .download: return "arrow.down.circle.fill"
        case .library: return "music.note.list"
        case .playlists: return "rectangle.stack.fill"
        case .settings: return "gear"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .download
    @State private var showFullPlayer = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DownloadView()
                    .tabItem {
                        Label(Tab.download.title, systemImage: Tab.download.icon)
                    }
                    .tag(Tab.download)

                LibraryView()
                    .tabItem {
                        Label(Tab.library.title, systemImage: Tab.library.icon)
                    }
                    .tag(Tab.library)

                PlaylistsView()
                    .tabItem {
                        Label(Tab.playlists.title, systemImage: Tab.playlists.icon)
                    }
                    .tag(Tab.playlists)

                SettingsView()
                    .tabItem {
                        Label(Tab.settings.title, systemImage: Tab.settings.icon)
                    }
                    .tag(Tab.settings)
            }
            .tint(DesignTokens.accentPrimary)
            .onAppear {
                // Configure tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(DesignTokens.backgroundPrimary)
                
                // Tab bar item colors
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor(DesignTokens.textSecondary)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor(DesignTokens.textSecondary)
                ]
                
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(DesignTokens.accentPrimary)
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(DesignTokens.accentPrimary)
                ]
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }

            // Mini player overlay
            if AudioPlayerService.shared.currentSong != nil {
                VStack {
                    if selectedTab == .download {
                        // Top position for Download tab
                        MiniPlayerView(showFullPlayer: $showFullPlayer)
                            .transition(.move(edge: .top))
                        Spacer()
                    } else {
                        // Bottom position for other tabs
                        Spacer()
                        MiniPlayerView(showFullPlayer: $showFullPlayer)
                            .padding(.bottom, 49) // Tab bar height
                            .transition(.move(edge: .bottom))
                    }
                }
                .animation(.easeInOut(duration: DesignTokens.animationSlow), value: selectedTab)
            }
        }
        .preferredColorScheme(.dark)
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

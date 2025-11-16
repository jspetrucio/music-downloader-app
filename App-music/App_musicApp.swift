//
//  App_musicApp.swift
//  App-music
//
//  Music Downloader - Main app entry point
//

import SwiftUI
import SwiftData

@main
struct App_musicApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [
            DownloadedSong.self,
            Playlist.self,
            DownloadHistory.self,
            QueueItem.self  // Added QueueItem to model container
        ])
    }
}

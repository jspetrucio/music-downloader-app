//
//  SettingsView.swift
//  App-music
//
//  Music Downloader - Settings view with storage management
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var songs: [DownloadedSong]
    @Query private var playlists: [Playlist]

    @State private var showClearCacheAlert = false
    @State private var showClearLibraryAlert = false

    private let storageManager = StorageManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Storage section
                Section {
                    storageStats
                } header: {
                    Text("Armazenamento")
                }

                // Actions section
                Section {
                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label("Limpar Cache", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        showClearLibraryAlert = true
                    } label: {
                        Label("Apagar Biblioteca", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Ações")
                }

                // About section
                Section {
                    aboutInfo
                } header: {
                    Text("Sobre")
                }
            }
            .navigationTitle("Ajustes")
            .alert("Limpar Cache", isPresented: $showClearCacheAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Limpar", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("Isso irá remover todos os arquivos de áudio do dispositivo, mas manterá os registros na biblioteca.")
            }
            .alert("Apagar Biblioteca", isPresented: $showClearLibraryAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Apagar Tudo", role: .destructive) {
                    clearLibrary()
                }
            } message: {
                Text("Isso irá remover TODOS os dados: músicas, playlists e histórico. Esta ação não pode ser desfeita.")
            }
        }
    }

    // MARK: - UI Components

    private var storageStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Espaço Usado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(storageManager.formattedStorageUsed())
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                Image(systemName: "internaldrive.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
            }

            Divider()

            // Statistics
            VStack(spacing: 12) {
                StatRow(label: "Músicas", value: "\(songs.count)")
                StatRow(label: "Playlists", value: "\(playlists.count)")
                StatRow(label: "Arquivos", value: "\(storageManager.audioFileCount())")
            }
        }
        .padding(.vertical, 8)
    }

    private var aboutInfo: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Versão")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Backend")
                Spacer()
                Text("localhost:8000")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            HStack(alignment: .top) {
                Text("Aviso Legal")
                Spacer()
                Text("Uso pessoal apenas")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func clearCache() {
        do {
            try storageManager.clearAllAudioFiles()
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }

    private func clearLibrary() {
        // Delete all songs
        for song in songs {
            modelContext.delete(song)
        }

        // Delete all playlists
        for playlist in playlists {
            modelContext.delete(playlist)
        }

        // Clear history
        let descriptor = FetchDescriptor<DownloadHistory>()
        if let histories = try? modelContext.fetch(descriptor) {
            for history in histories {
                modelContext.delete(history)
            }
        }

        // Save changes
        try? modelContext.save()

        // Clear files
        try? storageManager.clearAllAudioFiles()
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DownloadedSong.self, Playlist.self, DownloadHistory.self,
        configurations: config
    )

    return SettingsView()
        .modelContainer(container)
}

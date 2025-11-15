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
        ZStack {
            // Animated background
            AnimatedBackgroundView()
                .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.spacingMD) {
                        // Storage section
                        storageStatsCard
                        
                        // Actions section
                        actionsCard
                        
                        // About section
                        aboutCard
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingSM)
                    .padding(.bottom, DesignTokens.spacingXL)
                }
                .navigationTitle("Ajustes")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
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
        .preferredColorScheme(.dark)
    }

    // MARK: - UI Components

    private var storageStatsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            // Header
            HStack {
                Text("Armazenamento")
                    .font(.headline)
                    .foregroundColor(DesignTokens.textPrimary)
                
                Spacer()
                
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.accentPrimary, DesignTokens.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Divider()
                .background(DesignTokens.glassBorder)
            
            // Main storage display
            HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Espaço Usado")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.textSecondary)

                    Text(storageManager.formattedStorageUsed())
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignTokens.accentPrimary, DesignTokens.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
            }
            .padding(.vertical, DesignTokens.spacingXS)

            Divider()
                .background(DesignTokens.glassBorder)

            // Statistics grid
            VStack(spacing: DesignTokens.spacingSM) {
                StatRow(
                    icon: "music.note",
                    label: "Músicas",
                    value: "\(songs.count)",
                    color: DesignTokens.accentPrimary
                )
                
                StatRow(
                    icon: "rectangle.stack.fill",
                    label: "Playlists",
                    value: "\(playlists.count)",
                    color: DesignTokens.accentSecondary
                )
                
                StatRow(
                    icon: "doc.fill",
                    label: "Arquivos",
                    value: "\(storageManager.audioFileCount())",
                    color: DesignTokens.accentTertiary
                )
            }
        }
        .minimalistCard(padding: DesignTokens.spacingMD)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("Ações")
                .font(.headline)
                .foregroundColor(DesignTokens.textPrimary)
            
            Divider()
                .background(DesignTokens.glassBorder)
            
            VStack(spacing: DesignTokens.spacingSM) {
                // Clear cache button
                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "trash")
                            .foregroundStyle(DesignTokens.warning)
                            .font(.title3)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Limpar Cache")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.textPrimary)
                            
                            Text("Remove arquivos de áudio")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(DesignTokens.spacingSM)
                    .background(DesignTokens.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                            .stroke(DesignTokens.warning.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(DesignTokens.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
                
                // Clear library button
                Button {
                    showClearLibraryAlert = true
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(DesignTokens.error)
                            .font(.title3)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apagar Biblioteca")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.textPrimary)
                            
                            Text("Remove tudo permanentemente")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(DesignTokens.spacingSM)
                    .background(DesignTokens.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                            .stroke(DesignTokens.error.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(DesignTokens.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .minimalistCard(padding: DesignTokens.spacingMD)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("Sobre")
                .font(.headline)
                .foregroundColor(DesignTokens.textPrimary)
            
            Divider()
                .background(DesignTokens.glassBorder)
            
            VStack(spacing: DesignTokens.spacingSM) {
                AboutRow(label: "Versão", value: "1.0.0")
                AboutRow(label: "Backend", value: "localhost:8000")
                AboutRow(label: "Aviso Legal", value: "Uso pessoal apenas")
            }
        }
        .minimalistCard(padding: DesignTokens.spacingMD)
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
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.textPrimary)
        }
    }
}

// MARK: - About Row

struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.textPrimary)
                .multilineTextAlignment(.trailing)
        }
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

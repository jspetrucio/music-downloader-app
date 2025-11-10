//
//  FullPlayerView.swift
//  App-music
//
//  Music Downloader - Full screen player
//

import SwiftUI

struct FullPlayerView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    private let player = AudioPlayerService.shared

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                header

                Spacer()

                // Album art
                albumArt

                // Song info
                songInfo

                // Progress bar
                progressBar

                // Controls
                controls

                // Volume
                volumeControl

                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - UI Components

    private var header: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text("Tocando Agora")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Menu {
                Button {
                    // Add to playlist action
                } label: {
                    Label("Adicionar à Playlist", systemImage: "text.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var albumArt: some View {
        Group {
            if let song = player.currentSong,
               let thumbnailURL = song.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                        }
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 320, height: 320)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    private var songInfo: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.title ?? "Título Desconhecido")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(player.currentSong?.artist ?? "Artista Desconhecido")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(Color.accentColor)

            // Time labels
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatTime(player.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 32) {
            // Shuffle
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.isShuffleEnabled ? Color.accentColor : .secondary)
            }

            // Previous
            Button {
                player.playPrevious(modelContext: modelContext)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            // Play/Pause
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
            }

            // Next
            Button {
                player.playNext(modelContext: modelContext)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }

            // Repeat
            Button {
                player.toggleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode.iconName)
                    .font(.title3)
                    .foregroundStyle(player.repeatMode.isActive ? Color.accentColor : .secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var volumeControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(player.volume) },
                    set: { player.setVolume(Float($0)) }
                ),
                in: 0...1
            )
            .tint(Color.accentColor)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    FullPlayerView(isPresented: .constant(true))
}

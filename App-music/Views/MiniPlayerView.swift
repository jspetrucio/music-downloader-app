//
//  MiniPlayerView.swift
//  App-music
//
//  Music Downloader - Mini player bar
//

import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool

    private let player = AudioPlayerService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let song = player.currentSong,
               let thumbnailURL = song.thumbnailURL,
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentSong?.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(player.currentSong?.artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play/Pause button
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }

            // Next button
            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        .padding(.horizontal)
        .onTapGesture {
            showFullPlayer = true
        }
    }
}

#Preview {
    MiniPlayerView(showFullPlayer: .constant(false))
}

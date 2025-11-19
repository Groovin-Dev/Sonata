//
//  TrackRowView.swift
//  Sonata
//

import SwiftUI
import AppKit

struct TrackRowView: View {
    let track: Track
    var onPlay: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?
    var onShowDetails: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track, cornerRadius: 8)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    onPlay?()
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)

                Button {
                    onFavoriteToggle?()
                } label: {
                    Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(track.isFavorite ? .red : .primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onShowDetails?() }
        .contextMenu {
            Button("Play", action: { onPlay?() })
            if let url = track.shareURL {
                Button("Copy Share URL") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) }
            }
        }
    }
}

#Preview {
    TrackRowView(
        track: Track(trackId: "demo", title: "Cards", artist: "Ela Minus", duration: 240, isFavorite: false),
        onPlay: {},
        onFavoriteToggle: {},
        onShowDetails: {}
    )
}

//
//  TrackCardView.swift
//  Sonata
//

import SwiftUI
import AppKit

struct TrackCardView: View {
    let track: Track
    var onPlay: (() -> Void)? = nil
    var onFavoriteToggle: (() -> Void)? = nil
    var onShowDetails: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artworkLayer
            hoverControls
        }
        .frame(minWidth: 200, minHeight: 220)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.18 : 0.10), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 4 : 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onShowDetails?() }
        .contextMenu {
            Button("Play") { onPlay?() }
            if let url = track.shareURL {
                Button("Copy Share URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var artworkLayer: some View {
        ArtworkView(track: track, cornerRadius: 16)
            .aspectRatio(1, contentMode: .fill)
            .frame(maxHeight: .infinity)
            .clipped()
            .overlay(cardGradient)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
    }

    @ViewBuilder
    private var hoverControls: some View {
        HStack {
            Spacer()
            if isHovered {
                playButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
    }

    private var playButton: some View {
        Button {
            onPlay?()
        } label: {
            Image(systemName: "play.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .background(Color.accentColor, in: .circle)
        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 2)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.0),
                Color.black.opacity(0.18),
                Color.black.opacity(0.32)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    TrackCardView(track: Track(trackId: "demo-cards", title: "Cards", artist: "Ela Minus", duration: 248, isFavorite: false))
        .frame(width: 240)
        .padding()
}

//
//  TrackDetailView.swift
//  Sonata
//

import SwiftUI

struct TrackDetailView: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ArtworkView(track: track, cornerRadius: 12)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title)
                        .font(.title3.weight(.semibold))
                    Text(track.artist)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let url = track.shareURL {
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
                Spacer()
            }

            if !track.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(track.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassEffect(.regular, in: .capsule)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 240)
        .presentationDetents([.medium])
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
}

#Preview {
    TrackDetailView(
        track: Track(
            trackId: "demo",
            title: "Cards",
            artist: "Ela Minus",
            duration: 200,
            isFavorite: false,
            streamURL: nil,
            shareURL: URL(string: "https://hypem.com")
        )
    )
}

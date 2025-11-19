//
//  DiscoverView.swift
//  Sonata
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService

    private var tracks: [Track] {
        hypeMService.discoverTracks
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(tracks) { track in
                    TrackCardView(
                        track: track,
                        onPlay: {
                            playbackModel.setQueue(tracks, startAt: track)
                        },
                        onFavoriteToggle: {
                            let updated = hypeMService.toggleFavorite(for: track)
                            playbackModel.updateFavorite(with: updated)
                        }
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle("Discover")
    }
}

#Preview {
    DiscoverView()
        .environmentObject(PlaybackModel())
        .environmentObject(MockHypeMService())
}

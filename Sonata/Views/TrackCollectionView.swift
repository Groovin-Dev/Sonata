//
//  TrackCollectionView.swift
//  Sonata
//

import SwiftUI

struct TrackCollectionView: View {
    let title: String
    let tracks: [Track]
    let refresh: () async -> Void

    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService

    @State private var isLoading = false
    @State private var selectedTrack: Track?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.accentColor)
                }
            }
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(tracks) { track in
                        TrackCardView(
                            track: track,
                            onPlay: { playbackModel.setQueue(tracks, startAt: track) },
                            onFavoriteToggle: {
                                let updated = hypeMService.toggleFavorite(for: track)
                                playbackModel.updateFavorite(with: updated)
                            },
                            onShowDetails: { selectedTrack = track }
                        )
                    }
                }
                .padding(24)
                .padding(.bottom, 60)
            }
            .clipped()
        }
        .sheet(item: $selectedTrack) { track in
            TrackDetailView(track: track)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .keyboardShortcut("r")
                .disabled(isLoading)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await refresh()
    }
}

#Preview {
    TrackCollectionView(title: "Preview", tracks: [], refresh: {})
        .environmentObject(MockHypeMService())
        .environmentObject(PlaybackModel())
}

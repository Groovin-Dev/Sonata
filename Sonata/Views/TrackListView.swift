//
//  TrackListView.swift
//  Sonata
//

import SwiftUI

struct TrackListView: View {
    let title: String
    let tracks: [Track]
    let refresh: () async -> Void

    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if isLoading { ProgressView().progressViewStyle(.circular).tint(.accentColor) }
            }
            .padding(.horizontal)

            if tracks.isEmpty && !isLoading {
                Text("No tracks yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(tracks, id: \.id) { track in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(.headline)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            playbackModel.setQueue(tracks, startAt: track)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.automatic)

                        Button {
                            let updated = hypeMService.toggleFavorite(for: track)
                            playbackModel.updateFavorite(with: updated)
                        } label: {
                            Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(track.isFavorite ? .accentColor : .secondary)
                        }
                        .buttonStyle(.automatic)
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
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
    TrackListView(title: "Preview", tracks: [], refresh: {})
        .environmentObject(PlaybackModel())
        .environmentObject(MockHypeMService())
}

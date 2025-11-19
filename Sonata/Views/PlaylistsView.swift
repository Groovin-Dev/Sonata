//
//  PlaylistsView.swift
//  Sonata
//

import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var hypeMService: MockHypeMService
    @EnvironmentObject private var playbackModel: PlaybackModel
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Playlists")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                if isLoading { ProgressView().tint(.accentColor) }
            }
            .padding(.horizontal)

            List {
                ForEach(Array(hypeMService.playlistStore.keys.sorted()), id: \.self) { slot in
                    Section(header: Text("\(name(for: slot))")) {
                        let tracks = hypeMService.playlistStore[slot] ?? []
                        if tracks.isEmpty {
                            Text("No tracks in this playlist")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(tracks, id: \.id) { track in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(track.title).font(.headline)
                                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        playbackModel.setQueue(tracks, startAt: track)
                                    } label: {
                                        Image(systemName: "play.fill")
                                    }
                                    .buttonStyle(.automatic)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
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

    private func name(for slot: String) -> String {
        if let idx = Int(slot), hypeMService.playlistNames.indices.contains(idx - 1) {
            return hypeMService.playlistNames[idx - 1]
        }
        return "Playlist \(slot)"
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        _ = await hypeMService.refreshPlaylistsLive()
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(MockHypeMService())
        .environmentObject(PlaybackModel())
}

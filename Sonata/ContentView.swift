//
//  ContentView.swift
//  Sonata
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var navigationModel: NavigationModel
    @EnvironmentObject private var playbackModel: PlaybackModel
    @EnvironmentObject private var hypeMService: MockHypeMService

    var body: some View {
        Group {
            switch navigationModel.selectedSection {
            case .discover:
                TrackCollectionView(
                    title: "Discover",
                    tracks: hypeMService.discoverTracks,
                    refresh: { _ = await hypeMService.refreshDiscoverLive(section: "popular", mode: "noremix") }
                )
            case .trending:
                TrackCollectionView(
                    title: "Trending",
                    tracks: hypeMService.discoverTracks,
                    refresh: { _ = await hypeMService.refreshDiscoverLive(section: "popular", mode: "noremix") }
                )
            case .favorites:
                TrackCollectionView(
                    title: "Favorites",
                    tracks: hypeMService.fetchFavorites(),
                    refresh: { _ = await hypeMService.refreshFavoritesLive() }
                )
            case .queue:
                Text("Queue") // stub
            case .playlists:
                PlaylistsView()
            case .history:
                TrackCollectionView(
                    title: "History",
                    tracks: hypeMService.historyStore,
                    refresh: { _ = await hypeMService.refreshHistoryLive() }
                )
            case .downloads:
                Text("Downloads") // stub
            case .hypemFeed:
                TrackCollectionView(
                    title: "Feed",
                    tracks: hypeMService.feedStore,
                    refresh: { _ = await hypeMService.refreshFeedLive() }
                )
            case .hypemBlogs:
                BlogsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationModel())
        .environmentObject(PlaybackModel())
}

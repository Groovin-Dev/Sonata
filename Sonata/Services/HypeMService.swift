//
//  HypeMService.swift
//  Sonata
//

import Foundation
import Combine

@MainActor
protocol HypeMServing {
    func fetchDiscoverTracks() -> [Track]
    func fetchFavorites() -> [Track]
    func toggleFavorite(for track: Track) -> Track
    func streamURL(for track: Track) -> URL?
    func setAuthToken(_ token: String?)
    func loadPersistedToken()
}

@MainActor
final class MockHypeMService: ObservableObject, HypeMServing {
    @Published private(set) var discoverStore: [Track] = [
        Track(
            trackId: "ela-minus_cards",
            title: "Cards",
            artist: "Ela Minus",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/58/99238.jpg"),
            duration: 248,
            isFavorite: false,
            tags: ["electronic", "synth"],
            streamURL: HypeMAPIConfig.streamURL(for: "ela-minus_cards"),
            shareURL: HypeMAPIConfig.shareURL(for: "ela-minus_cards")
        ),
        Track(
            trackId: "yves-tumor_judith-hill",
            title: "Judith Hill",
            artist: "Yves Tumor",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/89/110890.jpg"),
            duration: 231,
            isFavorite: true,
            tags: ["art rock"],
            streamURL: HypeMAPIConfig.streamURL(for: "yves-tumor_judith-hill"),
            shareURL: HypeMAPIConfig.shareURL(for: "yves-tumor_judith-hill")
        ),
        Track(
            trackId: "idle-eyes_i-feel-high",
            title: "I Feel High",
            artist: "Idle Eyes",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/18/91618.jpg"),
            duration: 215,
            isFavorite: false,
            tags: ["indie", "dream pop"],
            streamURL: HypeMAPIConfig.streamURL(for: "idle-eyes_i-feel-high"),
            shareURL: HypeMAPIConfig.shareURL(for: "idle-eyes_i-feel-high")
        ),
        Track(
            trackId: "m83_midnight-city",
            title: "Midnight City",
            artist: "M83",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/46/73646.jpg"),
            duration: 243,
            isFavorite: false,
            tags: ["electro", "anthem"],
            streamURL: HypeMAPIConfig.streamURL(for: "m83_midnight-city"),
            shareURL: HypeMAPIConfig.shareURL(for: "m83_midnight-city")
        ),
        Track(
            trackId: "fleetwood-mac_dreams",
            title: "Dreams",
            artist: "Fleetwood Mac",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/85/39985_200.jpg"),
            duration: 257,
            isFavorite: true,
            tags: ["classic", "soft rock"],
            streamURL: HypeMAPIConfig.streamURL(for: "fleetwood-mac_dreams"),
            shareURL: HypeMAPIConfig.shareURL(for: "fleetwood-mac_dreams")
        ),
        Track(
            trackId: "mgmt_electric-feel",
            title: "Electric Feel",
            artist: "MGMT",
            artworkURL: URL(string: "https://static.hypem.com/assets/tiny/albums/05/43305.jpg"),
            duration: 229,
            isFavorite: false,
            tags: ["psychedelic"],
            streamURL: HypeMAPIConfig.streamURL(for: "mgmt_electric-feel"),
            shareURL: HypeMAPIConfig.shareURL(for: "mgmt_electric-feel")
        )
    ]
    @Published private(set) var favoritesStore: [Track] = []
    @Published private(set) var historyStore: [Track] = []
    @Published private(set) var feedStore: [Track] = []
    @Published private(set) var playlistStore: [String: [Track]] = [:]
    @Published private(set) var blogsStore: [Blog] = []
    @Published private(set) var playlistNames: [String] = []

    private let apiClient = HypeMAPIClient()
    private let tokenStore = TokenStore()
    private let credentialStore = KeychainCredentialStore()

    var discoverTracks: [Track] {
        discoverStore
    }

    func fetchDiscoverTracks() -> [Track] {
        discoverStore
    }

    func fetchFavorites() -> [Track] {
        if !favoritesStore.isEmpty {
            return favoritesStore
        }
        return discoverStore.filter { $0.isFavorite }
    }

    @discardableResult
    func toggleFavorite(for track: Track) -> Track {
        guard let idx = discoverStore.firstIndex(where: { $0.trackId == track.trackId }) else { return track }
        discoverStore[idx].isFavorite.toggle()
        let updated = discoverStore[idx]
        if updated.isFavorite {
            if !favoritesStore.contains(where: { $0.trackId == updated.trackId }) {
                favoritesStore.append(updated)
            }
        } else {
            favoritesStore.removeAll { $0.trackId == updated.trackId }
        }
        return updated
    }

    func streamURL(for track: Track) -> URL? {
        track.streamURL ?? HypeMAPIConfig.streamURL(for: track.trackId)
    }

    // Quick validation helper for live API. Not wired to UI yet; call manually when ready.
    @discardableResult
    func refreshFromWhatsNew() async throws -> [Track] {
        let live = try await apiClient.fetchWhatsNew()
        if !live.isEmpty {
            DispatchQueue.main.async {
                self.discoverStore = live
            }
        }
        return live
    }

    @MainActor
    func setAuthToken(_ token: String?) {
        apiClient.hmToken = token
        tokenStore.saveToken(token)
    }

    // Debug helpers
    @discardableResult
    func refreshFromWhatsNewDebug() async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        let result = try await apiClient.fetchWhatsNewDebug()
        if !result.tracks.isEmpty {
            DispatchQueue.main.async {
                self.discoverStore = result.tracks
            }
        }
        return result
    }

    func loginDebug(username: String, password: String, deviceIdOverride: String?) async throws -> (token: String, raw: String, status: Int, url: URL) {
        if let deviceIdOverride, !deviceIdOverride.isEmpty {
            return try await apiClient.loginDebug(username: username, password: password, deviceId: deviceIdOverride)
        }
        return try await apiClient.loginDebug(username: username, password: password)
    }

    func loadPersistedToken() {
        let token = tokenStore.loadToken()
        apiClient.hmToken = token
    }

    func loadSavedCredentials() -> (username: String, password: String)? {
        try? credentialStore.load()
    }

    func saveCredentials(username: String, password: String) {
        try? credentialStore.save(username: username, password: password)
    }

    func clearCredentials() {
        try? credentialStore.clear()
    }

    // Live data refresh; falls back to existing store if call fails.
    @discardableResult
    func refreshDiscoverLive(section: String = "popular", mode: String = "3day") async -> [Track] {
        do {
            let debug = try await apiClient.fetchPopularDebug(mode: "noremix", count: 50)
            log("Live fetch popular status=\(debug.status) count=\(debug.tracks.count) url=\(debug.url)")
            if !debug.tracks.isEmpty {
                DispatchQueue.main.async {
                    self.discoverStore = debug.tracks
                }
            }
            return debug.tracks
        } catch {
            return discoverStore
        }
    }

    @discardableResult
    func refreshFavoritesLive(page: Int = 1, count: Int = 100) async -> [Track] {
        do {
            let favorites = try await apiClient.fetchFavorites(page: page, count: count)
            DispatchQueue.main.async {
                self.favoritesStore = favorites
            }
            return favorites
        } catch {
            log("Favorites refresh failed: \(error)")
            return favoritesStore
        }
    }

    @discardableResult
    func refreshHistoryLive(page: Int = 1, count: Int = 50) async -> [Track] {
        do {
            let history = try await apiClient.fetchHistory(page: page, count: count)
            DispatchQueue.main.async {
                self.historyStore = history
            }
            return history
        } catch {
            log("History refresh failed: \(error)")
            return historyStore
        }
    }

    @discardableResult
    func refreshFeedLive(mode: String = "all", count: Int = 40, page: Int = 1) async -> [Track] {
        do {
            let feed = try await apiClient.fetchFeed(mode: mode, count: count, page: page)
            DispatchQueue.main.async {
                self.feedStore = feed
            }
            return feed
        } catch {
            log("Feed refresh failed: \(error)")
            return feedStore
        }
    }

    @discardableResult
    func refreshPlaylistsLive(slots: [Int] = [1, 2, 3]) async -> [String: [Track]] {
        var result: [String: [Track]] = [:]
        if let names = try? await apiClient.fetchPlaylistNames() {
            DispatchQueue.main.async {
                self.playlistNames = names
            }
        }
        for slot in slots {
            do {
                let tracks = try await apiClient.fetchPlaylist(slot: slot)
                result["\(slot)"] = tracks
            } catch {
                log("Playlist slot \(slot) fetch failed: \(error)")
            }
        }
        DispatchQueue.main.async {
            for (key, value) in result {
                self.playlistStore[key] = value
            }
        }
        return playlistStore
    }

    @discardableResult
    func refreshBlogsLive() async -> [Blog] {
        do {
            let blogs = try await apiClient.fetchBlogs()
            DispatchQueue.main.async {
                self.blogsStore = blogs
            }
            return blogs
        } catch {
            log("Blogs refresh failed: \(error)")
            return blogsStore
        }
    }

    func refreshBlogTracks(siteId: Int) async -> [Track] {
        do {
            return try await apiClient.fetchBlogTracks(siteId: siteId)
        } catch {
            log("Blog tracks fetch failed: \(error)")
            return []
        }
    }

    // Attempt auto-login if no token but credentials exist.
    func autoLoginIfNeeded() {
        guard apiClient.hmToken == nil, let creds = loadSavedCredentials() else { return }
        Task {
            do {
                let token = try await apiClient.login(username: creds.username, password: creds.password)
                setAuthToken(token)
            } catch {
                // ignore and keep mock data
            }
        }
    }

    /// Attempts to restore token or auto-login, then refreshes discover from live API; returns tracks if any.
    @MainActor
    func bootstrapAndMaybeRefresh(playbackModel: PlaybackModel) async {
        // Restore token or auto-login
        loadPersistedToken()
        log("Bootstrap: loaded persisted token? \(apiClient.hmToken != nil)")
        if apiClient.hmToken == nil, let creds = loadSavedCredentials() {
            log("Bootstrap: attempting auto-login with saved credentials for user \(creds.username)")
            if let token = try? await apiClient.login(username: creds.username, password: creds.password) {
                setAuthToken(token)
                log("Bootstrap: auto-login succeeded, token set")
            } else {
                log("Bootstrap: auto-login failed, staying mock")
            }
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = await self.refreshDiscoverLive(section: "popular", mode: "3day") }
            // stagger dependent calls slightly to avoid overlapping updates into the same Published sets
            group.addTask {
                _ = await self.refreshFavoritesLive()
                _ = await self.refreshHistoryLive()
            }
            group.addTask {
                _ = await self.refreshFeedLive()
                _ = await self.refreshPlaylistsLive()
            }
            group.addTask { _ = await self.refreshBlogsLive() }
        }

        let tracksToUse = discoverStore

        if playbackModel.currentTrack == nil {
            playbackModel.setQueue(tracksToUse)
        } else if playbackModel.queue.isEmpty {
            playbackModel.setQueue(tracksToUse, startAt: playbackModel.currentTrack)
        }
    }

    private func log(_ message: String) {
        print("[HypeMService] \(message)")
    }
}

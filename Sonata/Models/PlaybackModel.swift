//
//  PlaybackModel.swift
//  Sonata
//

import SwiftUI
import Combine
import AVFoundation

struct Track: Identifiable, Hashable {
    let trackId: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let artworkName: String?
    let duration: TimeInterval
    var isFavorite: Bool
    let source: String
    let tags: [String]
    let streamURL: URL?
    let shareURL: URL?

    var id: String { trackId }

    init(
        trackId: String = UUID().uuidString,
        title: String,
        artist: String,
        artworkURL: URL? = nil,
        artworkName: String? = nil,
        duration: TimeInterval,
        isFavorite: Bool,
        source: String = "HypeM",
        tags: [String] = [],
        streamURL: URL? = nil,
        shareURL: URL? = nil
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.artworkName = artworkName
        self.duration = duration
        self.isFavorite = isFavorite
        self.source = source
        self.tags = tags
        self.streamURL = streamURL
        self.shareURL = shareURL
    }
}

extension Track: Codable {
    private enum CodingKeys: String, CodingKey {
        case trackId, title, artist, artworkURL, artworkName, duration, isFavorite, source, tags, streamURL, shareURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try container.decode(String.self, forKey: .trackId)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        artworkName = try container.decodeIfPresent(String.self, forKey: .artworkName)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "HypeM"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        streamURL = try container.decodeIfPresent(URL.self, forKey: .streamURL)
        shareURL = try container.decodeIfPresent(URL.self, forKey: .shareURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trackId, forKey: .trackId)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
        try container.encodeIfPresent(artworkName, forKey: .artworkName)
        try container.encode(duration, forKey: .duration)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(source, forKey: .source)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(streamURL, forKey: .streamURL)
        try container.encodeIfPresent(shareURL, forKey: .shareURL)
    }
}

enum PlaybackState: Equatable {
    case idle
    case buffering
    case playing
    case failed(String)
}

enum RepeatMode {
    case off
    case all
    case one
}

final class PlaybackModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var state: PlaybackState = PlaybackState.idle
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Double = 0.8 {
        didSet {
            player?.volume = Float(volume)
            persistState()
        }
    }
    @Published var lastError: String?
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off

    private var currentIndex: Int? {
        guard let currentTrack else { return nil }
        return queue.firstIndex(where: { $0.id == currentTrack.id })
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var failureObserver: Any?
    private var stallObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private let cacheDirectory: URL
    private var cachingKeys: Set<String> = []
    private let stateKey = "PlaybackState_v1"
    private var pendingSeekTime: TimeInterval?

    init() {
        let baseCache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = baseCache.appendingPathComponent("AudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheDirectory = dir
        loadPersistedState()
    }

    deinit {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
        }
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
    }

    func prime(with track: Track?) {
        guard let track else { return }
        currentTrack = track
        duration = track.duration
        currentTime = 0
        persistState()
    }

    func play(_ track: Track) {
        prime(with: track)
        startPlayback(for: track)
        persistState()
    }

    func setQueue(_ tracks: [Track], startAt track: Track? = nil) {
        queue = tracks
        let startingTrack = track ?? tracks.first
        if let startingTrack {
            play(startingTrack)
        }
        persistState()
    }

    func playNext() {
        guard let index = currentIndex else {
            isPlaying = false
            return
        }
        let nextIndex = index + 1
        guard queue.indices.contains(nextIndex) else {
            isPlaying = false
            return
        }
        play(queue[nextIndex])
    }

    func playPrevious() {
        guard let index = currentIndex else { return }
        let targetIndex = max(index - 1, 0)
        play(queue[targetIndex])
    }

    func togglePlayPause() {
        guard let player else { return }
        switch player.timeControlStatus {
        case .playing:
            player.pause()
            isPlaying = false
        case .paused, .waitingToPlayAtSpecifiedRate:
            player.play()
            isPlaying = true
        @unknown default:
            break
        }
        persistState()
    }

    func toggleShuffle() {
        isShuffled.toggle()
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }

    func seek(toFraction fraction: Double) {
        guard let player, duration > 0 else { return }
        let clamped = min(max(fraction, 0), 1)
        let target = clamped * duration
        let cmTime = CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] _ in
            self?.currentTime = target
            self?.persistState()
        }
    }

    func updateFavorite(with updatedTrack: Track) {
        if let idx = queue.firstIndex(where: { $0.id == updatedTrack.id }) {
            queue[idx] = updatedTrack
        }

        if currentTrack?.id == updatedTrack.id {
            currentTrack = updatedTrack
        }
        persistState()
    }

    // MARK: - Private

    private func startPlayback(for track: Track) {
        guard let remoteURL = normalizedStreamURL(track.streamURL) else {
            isPlaying = false
            state = PlaybackState.failed("Missing stream URL")
            lastError = "Missing stream URL"
            log("Refusing to start playback: no streamURL for track \(track.trackId)")
            return
        }
        lastError = nil

        // Stream from network to avoid stale/unplayable cache; cache in background for potential reuse later.
        let playbackURL = remoteURL

        // Stop and clear any existing player/item before creating a new one to avoid overlapping playback.
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
        }

        let playerItem = AVPlayerItem(url: playbackURL)
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
        }
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)
        isPlaying = true
        state = PlaybackState.buffering
        log("Starting playback for track \(track.trackId) from \(playbackURL.absoluteString)")
        player?.play()

        if let seekTime = pendingSeekTime {
            let cmTime = CMTime(seconds: seekTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: cmTime)
            currentTime = seekTime
            pendingSeekTime = nil
        }

        // Begin background cache if not already cached (used only for faster subsequent starts)
        if cachedFileURL(for: track).map({ !FileManager.default.fileExists(atPath: $0.path) }) ?? false {
            Task.detached { [weak self] in
                await self?.cacheTrack(track, from: remoteURL)
            }
        }

        // Observe time to update UI
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
            }
            if
                let item = self.player?.currentItem,
                item.status == .readyToPlay,
                item.currentTime() >= item.duration
            {
                self.playNext()
            }
        }

        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleStatusChange(item)
            }
        }

        timeControlObserver = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.handleTimeControlChange(player.timeControlStatus)
            }
        }

        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { [weak self] note in
            let err = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?.localizedDescription ?? "Unknown error"
            self?.lastError = "Playback failed: \(err)"
            self?.state = PlaybackState.failed(err)
            self?.isPlaying = false
            self?.log("AVPlayerItemFailedToPlayToEndTime: \(err)")
        }

        stallObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: playerItem, queue: .main) { [weak self] _ in
            self?.state = PlaybackState.buffering
            self?.log("Playback stalled; buffering")
        }
    }

    private func cacheKey(for track: Track, url: URL) -> String {
        return "\(track.trackId)_\(url.lastPathComponent)"
    }

    private func cachedFileURL(for track: Track) -> URL? {
        guard let url = normalizedStreamURL(track.streamURL) else { return nil }
        let filename = cacheKey(for: track, url: url)
        return cacheDirectory.appendingPathComponent(filename)
    }

    private func cacheTrack(_ track: Track, from url: URL) async {
        let key = cacheKey(for: track, url: url)
        if cachingKeys.contains(key) { return }
        cachingKeys.insert(key)
        defer { cachingKeys.remove(key) }

        guard let destination = cachedFileURL(for: track) else { return }
        // If already cached, skip
        if FileManager.default.fileExists(atPath: destination.path) { return }

        do {
            let (temp, _) = try await URLSession.shared.download(from: url)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            // Ignore caching failures; streaming will continue
            await MainActor.run {
                self.lastError = "Cache failed: \(error.localizedDescription)"
                self.state = PlaybackState.failed(error.localizedDescription)
                self.log("Cache failed for \(track.trackId): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence

    private struct PersistedPlaybackState: Codable {
        let queue: [Track]
        let currentTrackId: String?
        let currentTime: Double
        let volume: Double
        let isPlaying: Bool
    }

    private func persistState() {
        let state = PersistedPlaybackState(
            queue: queue,
            currentTrackId: currentTrack?.id,
            currentTime: currentTime,
            volume: volume,
            isPlaying: isPlaying
        )
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateKey)
        } catch {
            // ignore persistence errors
        }
    }

    private func loadPersistedState() {
        guard
            let data = UserDefaults.standard.data(forKey: stateKey),
            let state = try? JSONDecoder().decode(PersistedPlaybackState.self, from: data)
        else { return }
        queue = state.queue
        if let currentId = state.currentTrackId, let match = state.queue.first(where: { $0.id == currentId }) {
            currentTrack = match
            pendingSeekTime = state.currentTime
            currentTime = state.currentTime
            duration = match.duration
            if state.isPlaying {
                play(match)
            }
        } else {
            currentTrack = state.queue.first
        }
        volume = state.volume
        isPlaying = false // will be set in play(match) if needed
    }

    private func normalizedStreamURL(_ url: URL?) -> URL? {
        guard var url else { return nil }
        if url.scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let upgraded = components?.url {
                url = upgraded
            }
        }
        return url
    }

    private func handleStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            state = PlaybackState.playing
            lastError = nil
            log("Item ready: duration=\(item.duration.seconds)s")
        case .failed:
            let errDesc: String
            if let error = item.error as NSError? {
                errDesc = "\(error.localizedDescription) (domain=\(error.domain) code=\(error.code))"
            } else {
                errDesc = "Unknown error"
            }
            let err = errDesc
            state = PlaybackState.failed(err)
            lastError = "Playback failed: \(err)"
            isPlaying = false
            log("Item failed: \(err)")
        case .unknown:
            state = PlaybackState.buffering
            log("Item status unknown; waiting")
        @unknown default:
            state = PlaybackState.buffering
        }
    }

    private func handleTimeControlChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            state = PlaybackState.playing
            isPlaying = true
        case .paused:
            isPlaying = false
        case .waitingToPlayAtSpecifiedRate:
            state = PlaybackState.buffering
        @unknown default:
            break
        }
        log("timeControlStatus changed to \(status.rawValue)")
    }

    private func log(_ message: String) {
        print("[Playback] \(message)")
    }
}

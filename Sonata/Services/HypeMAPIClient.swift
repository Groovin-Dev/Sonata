//
//  HypeMAPIClient.swift
//  Sonata
//

import Foundation

struct HypeMAPIConfig {
    static let baseURL = URL(string: "https://api.hypem.com/v2/")!
    static let streamBase = URL(string: "http://hypem.com/serve/public/")!
    static let shareBase = URL(string: "http://hypem.com/track/")!
    // Set via environment variable HYPEM_API_KEY
    static let defaultAPIKey = ProcessInfo.processInfo.environment["HYPEM_API_KEY"] ?? ""
    static let defaultUserAgent = "com.hypem.hyperadio/2.8.9 (iPadOS)"

    static func streamURL(for trackId: String) -> URL {
        HypeMAPIConfig.streamBase.appendingPathComponent(trackId)
    }

    static func shareURL(for trackId: String) -> URL {
        HypeMAPIConfig.shareBase.appendingPathComponent(trackId)
    }
}

/// Lightweight client that mirrors the Android app's request shape so we can validate the API quickly.
final class HypeMAPIClient {
    var hmToken: String?
    var apiKey: String
    var userAgent: String
    private let session: URLSession

    init(
        apiKey: String = HypeMAPIConfig.defaultAPIKey,
        hmToken: String? = nil,
        userAgent: String = HypeMAPIConfig.defaultUserAgent,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.hmToken = hmToken
        self.userAgent = userAgent
        self.session = session
    }

    func fetchWhatsNew(count: Int = 20, page: Int = 1) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchWhatsNewDebug(count: count, page: page)
        return tracks
    }

    func fetchWhatsNewDebug(count: Int = 20, page: Int = 1) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        let url = try buildWhatsNewURL(count: count, page: page)
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response, error) = await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
        if let error {
            throw HypeMError(status: status, body: rawString.isEmpty ? error.localizedDescription : rawString)
        }
        let tracks = data.map { decodeTracks(from: $0) } ?? []
        return (tracks, rawString, status, url)
    }

    func fetchPlaylist(
        playlistKey: String = "PlaylistPopular",
        section: String = "popular",
        mode: String = "3day",
        page: Int = 1,
        count: Int = 20
    ) async throws -> [Track] {
        guard let url = buildPlaylistURL(playlistKey: playlistKey, section: section, mode: mode, page: page, count: count) else { return [] }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _, error) = await perform(request: request)
        if let error { throw error }
        guard let data else { return [] }
        return decodeTracks(from: data)
    }

    func fetchPlaylistDebug(
        playlistKey: String = "PlaylistPopular",
        section: String = "popular",
        mode: String = "3day",
        page: Int = 1,
        count: Int = 20
    ) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard let url = buildPlaylistURL(playlistKey: playlistKey, section: section, mode: mode, page: page, count: count) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response, error) = await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
        if let error {
            throw HypeMError(status: status, body: rawString.isEmpty ? error.localizedDescription : rawString)
        }
        let tracks = data.map { decodeTracks(from: $0) } ?? []
        return (tracks, rawString, status, url)
    }

    func fetchPopular(mode: String = "noremix", count: Int = 50, page: Int = 1) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchPopularDebug(mode: mode, count: count, page: page)
        return tracks
    }

    func fetchPopularDebug(mode: String = "noremix", count: Int = 50, page: Int = 1) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("popular"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawString = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        let tracks = decodeTracks(from: data)
        return (tracks, rawString, status, url)
    }

    func fetchFavorites(page: Int = 1, count: Int = 100) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchFavoritesDebug(page: page, count: count)
        return tracks
    }

    func fetchFavoritesDebug(page: Int = 1, count: Int = 100) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/favorites"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        let tracks = decodeTracks(from: data, markFavorite: true)
        return (tracks, raw, status, url)
    }

    func fetchHistory(page: Int = 1, count: Int = 50) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchHistoryDebug(page: page, count: count)
        return tracks
    }

    func fetchHistoryDebug(page: Int = 1, count: Int = 50) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/history"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "count", value: String(count))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        let tracks = decodeTracks(from: data)
        return (tracks, raw, status, url)
    }

    func fetchFeedCount() async throws -> Int {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/feed/count"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "key", value: apiKey)]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        let decoded = String(data: data, encoding: .utf8) ?? "0"
        return Int(decoded) ?? 0
    }

    func fetchFeed(mode: String = "all", count: Int = 40, page: Int = 1) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchFeedDebug(mode: mode, count: count, page: page)
        return tracks
    }

    func fetchFeedDebug(mode: String = "all", count: Int = 40, page: Int = 1) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/feed"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        let tracks = decodeTracks(from: data)
        return (tracks, raw, status, url)
    }

    func login(username: String, password: String, deviceId: String? = nil) async throws -> String {
        let device = deviceId ?? DeviceIDGenerator.randomHex()
        let (token, _, _, _) = try await loginDebug(username: username, password: password, deviceId: device)
        return token
    }

    func loginDebug(username: String, password: String, deviceId: String? = nil) async throws -> (token: String, raw: String, status: Int, url: URL) {
        let url = HypeMAPIConfig.baseURL.appendingPathComponent("get_token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let hexDeviceId = DeviceIDGenerator.sanitize(deviceId ?? DeviceIDGenerator.randomHex())
        let bodyItems = [
            "username": username,
            "password": password,
            "key": apiKey,
            "device_id": hexDeviceId
        ]
        request.httpBody = formURLEncoded(bodyItems)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response, error) = await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
        if let error {
            throw HypeMError(status: status, body: rawString.isEmpty ? error.localizedDescription : rawString)
        }

        guard let data else {
            throw HypeMError(status: status, body: rawString)
        }

        let token = try decodeToken(from: data)
        hmToken = token
        return (token, rawString, status, url)
    }

    private func buildWhatsNewURL(count: Int, page: Int) throws -> URL {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("whats_new"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func buildPlaylistURL(playlistKey: String, section: String, mode: String, page: Int, count: Int) -> URL? {
        // Follows hypem://playlist/?key=PlaylistPopular&section=popular&mode=3day
        var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("playlist"), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "key", value: playlistKey),
            URLQueryItem(name: "section", value: section),
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "count", value: String(count))
        ]
        // API key gets appended too
        items.append(URLQueryItem(name: "key", value: apiKey))
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components?.queryItems = items
        return components?.url
    }

    private func perform(request: URLRequest) async -> (Data?, URLResponse?, Error?) {
        await withCheckedContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                continuation.resume(returning: (data, response, error))
            }
            task.resume()
        }
    }

    // Proper form encoding for application/x-www-form-urlencoded (spaces -> +, reserved chars percent escaped).
    private func formURLEncoded(_ params: [String: String]) -> Data? {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        let encoded = params.map { key, value -> String in
            let encKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encVal = value
                .replacingOccurrences(of: " ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encKey)=\(encVal)"
        }
        return encoded.joined(separator: "&").data(using: .utf8)
    }

    private func decodeTracks(from data: Data, markFavorite: Bool = false) -> [Track] {
        if let decoded = try? JSONDecoder().decode([APITrack].self, from: data) {
            return decoded.compactMap { $0.asTrack(isFavorite: markFavorite) }
        }
        guard
            let raw = try? JSONSerialization.jsonObject(with: data, options: []),
            let array = raw as? [Any]
        else { return [] }

        return array.compactMap { element in
            guard let dict = element as? [String: Any] else { return nil }
            return APITrack(dict: dict).asTrack(isFavorite: markFavorite)
        }
    }

    private func decodeToken(from data: Data) throws -> String {
        struct TokenResponse: Decodable { let hm_token: String? }
        if let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data), let token = decoded.hm_token {
            return token
        }
        if
            let raw = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = raw as? [String: Any],
            let token = dict["hm_token"] as? String
        {
            return token
        }
        throw URLError(.cannotParseResponse)
    }

    func fetchPlaylistNames() async throws -> [String] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/playlist_names"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "key", value: apiKey)]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return []
    }

    func fetchPlaylist(slot: Int) async throws -> [Track] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("me/playlists/\(slot)"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [URLQueryItem(name: "key", value: apiKey)]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        guard (200..<300).contains(status) else {
            throw HypeMError(status: status, body: raw)
        }
        return decodeTracks(from: data, markFavorite: slot == 1) // slot 1 is usually favorites
    }

    func fetchBlogs() async throws -> [Blog] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("blogs"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        if let decoded = try? JSONDecoder().decode([Blog].self, from: data) {
            return decoded
        }
        return []
    }

    func fetchBlog(siteId: Int) async throws -> Blog? {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("blogs/\(siteId)"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        if let decoded = try? JSONDecoder().decode(Blog.self, from: data) {
            return decoded
        }
        return nil
    }

    func fetchBlogTracks(siteId: Int) async throws -> [Track] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("blogs/\(siteId)/tracks"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return decodeTracks(from: data)
    }

    func fetchTracks(mode: String = "remix", count: Int = 50, page: Int = 1) async throws -> [Track] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("tracks"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return decodeTracks(from: data)
    }

    func fetchTrackBlogs(trackId: String) async throws -> [Blog] {
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("tracks/\(trackId)/blogs"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        if let decoded = try? JSONDecoder().decode([Blog].self, from: data) {
            return decoded
        }
        return []
    }

    func fetchTagTracks(tag: String, count: Int = 50, page: Int = 1) async throws -> [Track] {
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        guard var components = URLComponents(url: HypeMAPIConfig.baseURL.appendingPathComponent("tags/\(encoded)/tracks"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "count", value: String(count))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return decodeTracks(from: data)
    }
}

struct HypeMError: LocalizedError {
    let status: Int
    let body: String
    var errorDescription: String? { "HTTP \(status): \(body)" }
}

struct Blog: Decodable, Identifiable {
    let siteid: Int
    let sitename: String
    let siteurl: String?
    let blog_image: String?
    let blog_image_small: String?
    let followers: Int?
    let region_name: String?
    let total_tracks: Int?

    var id: Int { siteid }
}

enum DeviceIDGenerator {
    // HypeM server expects hex for device_id (Android client passes a device hash).
    static func randomHex() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sanitize(_ input: String) -> String {
        let hexChars = input.lowercased().filter { "0123456789abcdef".contains($0) }
        if hexChars.count >= 16 {
            return String(hexChars.prefix(32))
        }
        // Too short / empty: return random.
        return randomHex()
    }
}
private struct APITrack: Decodable {
    let itemid: String?
    let mediaid: String?
    let id: String?
    let title: String?
    let artist: String?
    let duration: Double?
    let time: Double?
    let thumb_url: String?
    let thumb_url_medium: String?
    let thumb_url_large: String?
    let stream_pub: String?
    let stream_url: String?
    let dateposted: Double?
    
    init(
        itemid: String? = nil,
        mediaid: String? = nil,
        id: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        duration: Double? = nil,
        time: Double? = nil,
        thumb_url: String? = nil,
        thumb_url_medium: String? = nil,
        thumb_url_large: String? = nil,
        stream_pub: String? = nil,
        stream_url: String? = nil,
        dateposted: Double? = nil
    ) {
        self.itemid = itemid
        self.mediaid = mediaid
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.time = time
        self.thumb_url = thumb_url
        self.thumb_url_medium = thumb_url_medium
        self.thumb_url_large = thumb_url_large
        self.stream_pub = stream_pub
        self.stream_url = stream_url
        self.dateposted = dateposted
    }
    
    init(dict: [String: Any]) {
        self.init(
            itemid: dict["itemid"] as? String,
            mediaid: dict["mediaid"] as? String,
            id: dict["id"] as? String,
            title: dict["title"] as? String,
            artist: dict["artist"] as? String,
            duration: dict["duration"] as? Double ?? dict["time"] as? Double,
            time: dict["time"] as? Double,
            thumb_url: dict["thumb_url"] as? String,
            thumb_url_medium: dict["thumb_url_medium"] as? String,
            thumb_url_large: dict["thumb_url_large"] as? String,
            stream_pub: dict["stream_pub"] as? String,
            stream_url: dict["stream_url"] as? String,
            dateposted: dict["dateposted"] as? Double
        )
    }
    
    func asTrack(isFavorite: Bool = false) -> Track? {
        let trackId = itemid ?? mediaid ?? id ?? UUID().uuidString
        let artURLString = thumb_url_large ?? thumb_url_medium ?? thumb_url
        let artURL = artURLString.flatMap(URL.init)

        // Skip entries that clearly aren't tracks (common in what's_new menu payloads).
        if title == nil, artist == nil, artURL == nil {
            return nil
        }

        return Track(
            trackId: trackId,
            title: title ?? "Untitled",
            artist: artist ?? "Unknown",
            artworkURL: artURL,
            duration: duration ?? time ?? 0,
            isFavorite: isFavorite,
            streamURL: (stream_pub ?? stream_url).flatMap(URL.init) ?? HypeMAPIConfig.streamURL(for: trackId),
            shareURL: HypeMAPIConfig.shareURL(for: trackId)
        )
    }
}

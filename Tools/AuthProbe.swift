import Foundation

@main
struct AuthProbe {
    static func main() async {
        let env = Env()
        guard let username = env["HYPEM_USERNAME"],
              let password = env["HYPEM_PASSWORD"] else {
            print(
                """
                Missing env vars. Set:
                  HYPEM_USERNAME=your_username
                  HYPEM_PASSWORD=your_password
                Optional:
                  HYPEM_DEVICE_ID=hex_device_id (defaults to random hex)
                  HYPEM_API_KEY=override_api_key
                """
            )
            exit(1)
        }

        guard let apiKey = env["HYPEM_API_KEY"] else {
            print("Missing HYPEM_API_KEY environment variable")
            exit(1)
        }

        let config = Config(
            apiKey: apiKey,
            deviceId: sanitize(env["HYPEM_DEVICE_ID"] ?? randomHex())
        )

        print("Logging in as \(username) device_id=\(config.deviceId)")
        do {
            let client = HypeMAPIClient(config: config)
            let token = try await client.login(username: username, password: password)
            print("Login ok hm_token=\(token)")

            do {
                let popular = try await client.fetchPopular(mode: "noremix", count: 50, page: 1)
                print("OK /v2/popular noremix -> \(popular.count) tracks")
                if let first = popular.first {
                    print("    First: \(first.displayTitle) – \(first.displayArtist)")
                }
            } catch {
                print("ERR /v2/popular: \(error.localizedDescription)")
            }

            // Legacy playlist routes (expected 404); keep for reference
            for route in [
                PlaylistRoute(key: "PlaylistPopular", section: "popular", mode: "3day"),
                PlaylistRoute(key: "PlaylistLatest", section: "tracks", mode: "all"),
                PlaylistRoute(key: "PlaylistFavorites", section: "users", mode: "all", needsAuth: true),
                PlaylistRoute(key: "PlaylistFeed", section: "feed", mode: "all", needsAuth: true),
                PlaylistRoute(key: "PlaylistHistory", section: "history", mode: "all", needsAuth: true)
            ] {
                do {
                    let tracks = try await client.fetchPlaylist(route: route)
                    print("LEGACY OK \(route.description) -> \(tracks.count) tracks")
                } catch {
                    print("LEGACY ERR \(route.description): \(error.localizedDescription)")
                }
            }
            exit(0)
        } catch {
            print("Login error: \(error.localizedDescription)")
            exit(1)
        }
    }
}

// MARK: - Client

struct Config {
    let apiKey: String
    let deviceId: String
    let userAgent = "com.hypem.hyperadio/2.8.9 (iPadOS)"
    let base = URL(string: "https://api.hypem.com/v2/")!
}

struct PlaylistRoute {
    let key: String
    let section: String
    let mode: String
    let needsAuth: Bool

    var description: String { "\(key) section=\(section) mode=\(mode)" }

    init(key: String, section: String, mode: String, needsAuth: Bool = false) {
        self.key = key
        self.section = section
        self.mode = mode
        self.needsAuth = needsAuth
    }
}

final class HypeMAPIClient {
    private let config: Config
    private var hmToken: String?

    init(config: Config) {
        self.config = config
    }

    func login(username: String, password: String) async throws -> String {
        let url = config.base.appendingPathComponent("get_token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.addValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: String] = [
            "username": username,
            "password": password,
            "key": config.apiKey,
            "device_id": config.deviceId
        ]
        request.httpBody = formEncoded(body)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
            throw ProbeError(message: "Login failed status=\(status) body=\(raw)")
        }
        guard let token = try decodeToken(from: data) else {
            let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
            throw ProbeError(message: "Login parse failed body=\(raw)")
        }
        hmToken = token
        return token
    }

    func fetchPopular(mode: String = "noremix", count: Int = 50, page: Int = 1) async throws -> [Track] {
        let (tracks, _, _, _) = try await fetchPopularDebug(mode: mode, count: count, page: page)
        return tracks
    }

    func fetchPopularDebug(mode: String = "noremix", count: Int = 50, page: Int = 1) async throws -> (tracks: [Track], raw: String, status: Int, url: URL) {
        guard var components = URLComponents(url: config.base.appendingPathComponent("popular"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var items = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "key", value: config.apiKey),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "page", value: String(page))
        ]
        if let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.addValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        guard status == 200 else {
            throw ProbeError(message: "Popular failed status=\(status) body=\(raw)")
        }
        let tracks = decodeTracks(from: data)
        return (tracks, raw, status, url)
    }

    func fetchPlaylist(route: PlaylistRoute, page: Int = 1, count: Int = 20) async throws -> [Track] {
        guard let url = buildPlaylistURL(route: route, page: page, count: count) else {
            throw ProbeError(message: "Bad playlist URL")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.addValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
            throw ProbeError(message: "Playlist failed \(route.description) status=\(status) body=\(raw)")
        }
        return decodeTracks(from: data)
    }

    private func buildPlaylistURL(route: PlaylistRoute, page: Int, count: Int) -> URL? {
        var components = URLComponents(url: config.base.appendingPathComponent("playlist"), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "key", value: route.key),
            URLQueryItem(name: "section", value: route.section),
            URLQueryItem(name: "mode", value: route.mode),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "key", value: config.apiKey)
        ]
        if route.needsAuth, let hmToken {
            items.append(URLQueryItem(name: "hm_token", value: hmToken))
        }
        components?.queryItems = items
        return components?.url
    }
}

// MARK: - Models / Helpers

struct Track: Decodable {
    let itemid: String?
    let mediaid: String?
    let id: String?
    let title: String?
    let artist: String?
    let duration: Double?
    let time: Double?

    var displayTitle: String { title ?? "Untitled" }
    var displayArtist: String { artist ?? "Unknown" }
}

private func decodeTracks(from data: Data) -> [Track] {
    if let decoded = try? JSONDecoder().decode([Track].self, from: data) {
        return decoded
    }
    if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        return raw.compactMap { dict in
            let itemid = dict["itemid"] as? String
            let mediaid = dict["mediaid"] as? String
            let id = dict["id"] as? String
            let title = dict["title"] as? String
            let artist = dict["artist"] as? String
            let duration = dict["duration"] as? Double ?? dict["time"] as? Double
            let time = dict["time"] as? Double
            return Track(itemid: itemid, mediaid: mediaid, id: id, title: title, artist: artist, duration: duration, time: time)
        }
    }
    return []
}

private func decodeToken(from data: Data) throws -> String? {
    struct TokenResponse: Decodable { let hm_token: String? }
    if let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) {
        return decoded.hm_token
    }
    if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        return raw["hm_token"] as? String
    }
    return nil
}

private func sanitize(_ deviceId: String) -> String {
    let hex = deviceId.lowercased().filter { "0123456789abcdef".contains($0) }
    if hex.count >= 16 {
        return String(hex.prefix(32))
    }
    return randomHex()
}

private func randomHex() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return bytes.map { String(format: "%02x", $0) }.joined()
}

private func formEncoded(_ params: [String: String]) -> Data? {
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

struct ProbeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Env {
    subscript(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}

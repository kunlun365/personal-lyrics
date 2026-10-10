import Foundation

/// Default, no-auth lyrics provider backed by lrclib.net's public API.
final class LRCLibProvider: LyricsProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(artist: String, title: String, duration: TimeInterval, album: String) async -> LyricsResult {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
//            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
            URLQueryItem(name: "duration", value: String(duration)),
            URLQueryItem(name: "album_name", value: album),
        ]
        guard let url = components.url else { return .none }

        var request = URLRequest(url: url)
        request.setValue("MacSpotifyLyrics/0.1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .none
            }
            let payload = try JSONDecoder().decode(Response.self, from: data)

            if let syncedLyrics = payload.syncedLyrics,
               let lines = LRCParser.parse(syncedLyrics),
               !lines.isEmpty {
                return .synced(lines)
            }
            if let plainLyrics = payload.plainLyrics, !plainLyrics.isEmpty {
                return .plain(plainLyrics)
            }
            return .none
        } catch {
            return .none
        }
    }

    private struct Response: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}

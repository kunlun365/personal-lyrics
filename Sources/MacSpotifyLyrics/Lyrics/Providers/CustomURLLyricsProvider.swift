import Foundation

/// A user-configured lyrics source: a URL template with {artist}/{title}/{duration}
/// placeholders, optionally with a user-supplied API key header. The credential (if any)
/// belongs to the user, not the app — nothing here is bundled or required by default.
///
/// Response body is parsed leniently: first as JSON matching lrclib's {plainLyrics,
/// syncedLyrics} shape, falling back to treating the raw body as LRC text, then as plain text.
final class CustomURLLyricsProvider: LyricsProvider {
    private let urlTemplate: String
    private let apiKeyHeaderName: String?
    private let apiKeyValue: String?
    private let session: URLSession

    init(
        urlTemplate: String,
        apiKeyHeaderName: String?,
        apiKeyValue: String?,
        session: URLSession = .shared
    ) {
        self.urlTemplate = urlTemplate
        self.apiKeyHeaderName = apiKeyHeaderName
        self.apiKeyValue = apiKeyValue
        self.session = session
    }

    func fetch(
        artist: String,
        title: String,
        duration: TimeInterval,
        album: String
    ) async -> LyricsResult {
        let allowed = CharacterSet.urlQueryAllowed
        let encodedArtist =
            artist.addingPercentEncoding(withAllowedCharacters: allowed)
            ?? artist
        let encodedTitle =
            title.addingPercentEncoding(withAllowedCharacters: allowed) ?? title
        let encodedAlbum =
            album.addingPercentEncoding(withAllowedCharacters: allowed) ?? album
        let durationString = String(Int(duration.rounded()))

        let resolvedURLString =
            urlTemplate
            .replacingOccurrences(of: "{artist}", with: encodedArtist)
            .replacingOccurrences(of: "{title}", with: encodedTitle)
            .replacingOccurrences(of: "{album}", with: encodedAlbum)
            .replacingOccurrences(of: "{duration}", with: durationString)
        print("请求：\(resolvedURLString)")

        guard let url = URL(string: resolvedURLString) else { return .none }
        
        var request = URLRequest(url: url)
        if let apiKeyHeaderName, let apiKeyValue, !apiKeyHeaderName.isEmpty {
            request.setValue(apiKeyValue, forHTTPHeaderField: apiKeyHeaderName)
        }

        do {
            let (data, response) = try await session.data(for: request)
//            if let body = String(data: data, encoding: .utf8) {
//                print("响应：\(body)")
//            }
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                return .none
            }

            if let payload = try? JSONDecoder().decode(
                LRCLibStyleResponse.self,
                from: data
            ) {
                if let syncedLyrics = payload.syncedLyrics,
                    let lines = LRCParser.parse(syncedLyrics), !lines.isEmpty
                {
                    return .synced(lines)
                }
                if let plainLyrics = payload.plainLyrics, !plainLyrics.isEmpty {
                    return .plain(plainLyrics)
                }
                return .none
            }

            guard let bodyText = String(data: data, encoding: .utf8),
                !bodyText.isEmpty
            else {
                return .none
            }
            if let lines = LRCParser.parse(bodyText), !lines.isEmpty {
                return .synced(lines)
            }
            return .plain(bodyText)
        } catch {
            return .none
        }
    }

    private struct LRCLibStyleResponse: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}

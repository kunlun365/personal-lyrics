import Foundation

/// TODO: add disk-backed persistence.
final class LyricsCache {
    private var memoryCache: [String: LyricsResult] = [:]

    private func key(artist: String, title: String, duration: TimeInterval, album: String) -> String {
        "\(artist)|\(title)|\(duration)|\(album)"
    }

    func get(artist: String, title: String, duration: TimeInterval, album: String) -> LyricsResult? {
        memoryCache[key(artist: artist, title: title, duration: duration, album: album)]
    }

    func set(artist: String, title: String, duration: TimeInterval, album: String, result: LyricsResult) {
        memoryCache[key(artist: artist, title: title, duration: duration, album: album)] = result
    }

    func clear() {
        memoryCache.removeAll()
    }
}

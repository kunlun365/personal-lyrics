import Foundation

protocol LyricsProvider {
    func fetch(artist: String, title: String, duration: TimeInterval, album: String) async -> LyricsResult
}

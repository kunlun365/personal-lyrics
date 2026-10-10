import Foundation

/// Tries lyrics providers in order, returns the first non-.none result.
final class LyricsSourceChain {
    private var providers: [LyricsProvider]

    init(providers: [LyricsProvider] = [LRCLibProvider()]) {
        self.providers = providers
    }

    func resolve(artist: String, title: String, duration: TimeInterval, album: String) async -> LyricsResult {
        for provider in providers {
            let result = await provider.fetch(artist: artist, title: title, duration: duration, album: album)
            if result != .none {
                return result
            }
        }
        return .none
    }
}

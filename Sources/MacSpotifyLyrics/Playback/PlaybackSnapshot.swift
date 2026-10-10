import Foundation

struct PlaybackSnapshot: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
}

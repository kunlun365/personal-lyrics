import Foundation

struct LyricLine: Equatable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
}

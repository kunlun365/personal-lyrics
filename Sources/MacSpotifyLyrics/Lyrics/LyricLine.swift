import Foundation

struct LyricLine: Equatable, Identifiable, Codable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
    
    private enum CodingKeys: String, CodingKey{
        case timestamp, text
    }
}

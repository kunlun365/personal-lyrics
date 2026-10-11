enum LyricsResult: Equatable {
    case synced([LyricLine])
    case plain(String)
    case none
}

extension LyricsResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, lines, text
    }
    
    private enum Kind: String, Codable {
        case synced, plain, none
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .synced:
            self = .synced(try container.decode([LyricLine].self, forKey: .lines))
        case .plain:
            self = .plain(try container.decode(String.self, forKey: .text))
        case .none:
            self = .none
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .synced(let lines):
            try container.encode(Kind.synced, forKey: .kind)
            try container.encode(lines, forKey: .lines)
        case .plain(let text):
            try container.encode(Kind.plain, forKey: .kind)
            try container.encode(text, forKey: .text)
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        }
    }
}

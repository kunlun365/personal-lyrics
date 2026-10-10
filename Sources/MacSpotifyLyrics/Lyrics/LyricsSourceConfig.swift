import Foundation

enum LyricsSourceKind: String, Codable {
    case lrclib
    case customURL
}

/// User-configurable lyrics source. Sources are tried in list order by `LyricsSourceChain`,
/// first non-.none match wins. `customURL` sources are entirely user-supplied (URL, optional
/// API key) — the app never bundles or requires credentials for the default `lrclib` source.
struct LyricsSourceConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: LyricsSourceKind
    var name: String
    /// For `.customURL` only. Supports {artist}, {title}, {duration} placeholders.
    var urlTemplate: String?
    var apiKeyHeaderName: String?
    var apiKeyValue: String?
    var isEnabled: Bool = true

    static let defaultSources: [LyricsSourceConfig] = [
        LyricsSourceConfig(kind: .lrclib, name: "LRCLib (默认)")
    ]
}

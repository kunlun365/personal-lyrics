import Foundation

enum LyricsProviderFactory {
    static func makeProvider(for config: LyricsSourceConfig) -> LyricsProvider? {
        guard config.isEnabled else { return nil }
        switch config.kind {
        case .lrclib:
            return LRCLibProvider()
        case .customURL:
            guard let template = config.urlTemplate, !template.isEmpty else { return nil }
            return CustomURLLyricsProvider(
                urlTemplate: template,
                apiKeyHeaderName: config.apiKeyHeaderName,
                apiKeyValue: config.apiKeyValue
            )
        }
    }

    static func makeProviders(for configs: [LyricsSourceConfig]) -> [LyricsProvider] {
        configs.compactMap(makeProvider)
    }
}

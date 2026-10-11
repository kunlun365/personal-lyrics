import Foundation

final class SettingsStore: ObservableObject {
    static let defaultOverlayOpacity = 0.85
    static let defaultTextSize = 18.0
    static let defaultFontName = "System"

    @Published var lyricsSources: [LyricsSourceConfig] {
        didSet { persistLyricsSources() }
    }
    @Published var overlayOpacity: Double {
        didSet { UserDefaults.standard.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }
    @Published var backgroundColor: CodableColor {
        didSet { persistColor(backgroundColor, key: Keys.backgroundColor) }
    }
    @Published var textColor: CodableColor {
        didSet { persistColor(textColor, key: Keys.textColor) }
    }
    /// A font family name (from NSFontManager), or "System" for the default system font.
    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: Keys.fontName) }
    }
    /// Point size of the current lyric line; other lines/header scale off this. Fixed regardless
    /// of panel size — resizing the panel changes layout, not glyph size.
    @Published var textSize: Double {
        didSet { UserDefaults.standard.set(textSize, forKey: Keys.textSize) }
    }
    @Published var windowFrameString: String? {
        didSet { UserDefaults.standard.set(windowFrameString, forKey: Keys.windowFrameString) }
    }
    @Published var menuBarLyricsEnabled: Bool {
        didSet { UserDefaults.standard.set(menuBarLyricsEnabled, forKey: Keys.menuBarLyricsEnabled) }
    }
    @Published var touchBarLyricsEnabled: Bool {
        didSet { UserDefaults.standard.set(touchBarLyricsEnabled, forKey: Keys.touchBarLyricsEnabled) }
    }
    @Published var overlayVisible: Bool {
        didSet { UserDefaults.standard.set(overlayVisible, forKey: Keys.overlayVisible) }
    }

    private enum Keys {
        static let lyricsSources = "lyricsSources"
        static let overlayOpacity = "overlayOpacity"
        static let backgroundColor = "backgroundColor"
        static let textColor = "textColor"
        static let fontName = "fontName"
        static let textSize = "textSize"
        static let windowFrameString = "windowFrameString"
        static let menuBarLyricsEnabled = "menuBarLyricsEnabled"
        static let touchBarLyricsEnabled = "touchBarLyricsEnabled"
        static let overlayVisible = "overlayVisible"
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Keys.lyricsSources),
           let decoded = try? JSONDecoder().decode([LyricsSourceConfig].self, from: data) {
            self.lyricsSources = decoded
        } else {
            self.lyricsSources = LyricsSourceConfig.defaultSources
        }

        let storedOpacity = UserDefaults.standard.object(forKey: Keys.overlayOpacity) as? Double
        self.overlayOpacity = storedOpacity ?? Self.defaultOverlayOpacity

        self.backgroundColor = Self.loadColor(forKey: Keys.backgroundColor) ?? .black
        self.textColor = Self.loadColor(forKey: Keys.textColor) ?? .white
        self.fontName = UserDefaults.standard.string(forKey: Keys.fontName) ?? Self.defaultFontName

        let storedTextSize = UserDefaults.standard.object(forKey: Keys.textSize) as? Double
        self.textSize = storedTextSize ?? Self.defaultTextSize

        self.windowFrameString = UserDefaults.standard.string(forKey: Keys.windowFrameString)

        self.menuBarLyricsEnabled = UserDefaults.standard.object(forKey: Keys.menuBarLyricsEnabled) as? Bool ?? true
        self.touchBarLyricsEnabled = UserDefaults.standard.object(forKey: Keys.touchBarLyricsEnabled) as? Bool ?? false
        self.overlayVisible = UserDefaults.standard.object(forKey: Keys.overlayVisible) as? Bool ?? false
    }

    func resetToDefaults() {
        lyricsSources = LyricsSourceConfig.defaultSources
        overlayOpacity = Self.defaultOverlayOpacity
        backgroundColor = .black
        textColor = .white
        fontName = Self.defaultFontName
        textSize = Self.defaultTextSize
        windowFrameString = nil
        menuBarLyricsEnabled = false
        touchBarLyricsEnabled = false
        overlayVisible = false
    }

    private func persistLyricsSources() {
        guard let data = try? JSONEncoder().encode(lyricsSources) else { return }
        UserDefaults.standard.set(data, forKey: Keys.lyricsSources)
    }

    private func persistColor(_ color: CodableColor, key: String) {
        guard let data = try? JSONEncoder().encode(color) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadColor(forKey key: String) -> CodableColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CodableColor.self, from: data)
    }
}

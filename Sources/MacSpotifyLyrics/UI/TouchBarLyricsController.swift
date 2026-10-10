import AppKit
import Combine

/// Publishes the current synced lyric line to the Touch Bar, visible no matter which app is
/// frontmost. See `TouchBarPrivateAPI` for why the public `NSTouchBar` API cannot be used from a
/// menu bar app.
///
/// Two surfaces are used together, because a Control Strip tray item alone is capped at a slot far
/// too narrow to read a lyric in:
///
/// * a compact item in the Control Strip — the persistent anchor, and the tap target;
/// * a bar presented into the main Touch Bar region, which is wide enough to actually read.
///
/// The presented bar uses placement 0, so the Control Strip stays visible next to it and its
/// buttons remain reachable. Tapping the Control Strip item collapses or restores the wide bar.
final class TouchBarLyricsController: NSObject, NSTouchBarDelegate {
    private static let trayItemIdentifier = NSTouchBarItem.Identifier(
        "com.adaptivid.floatingspotifylyrics.controlstrip.lyrics"
    )
    private static let wideItemIdentifier = NSTouchBarItem.Identifier(
        "com.adaptivid.floatingspotifylyrics.modal.lyrics"
    )

    /// The Control Strip caps this regardless of what we ask for; it only ever shows a word or so.
    private static let trayWidth: CGFloat = 150
    /// The main region is far roomier. Sized to fill it while leaving the Control Strip in place.
    private static let wideWidth: CGFloat = 620
    private static let itemHeight: CGFloat = 30
    private static let placeholderText = "♪"

    private let appState: AppState
    private let settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    /// Each view can live in only one place, so the tray and the wide bar get their own; both are
    /// updated together.
    private let trayMarquee: TouchBarMarqueeView
    private let wideMarquee: TouchBarMarqueeView
    private let trayItem: NSCustomTouchBarItem

    private lazy var wideBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [Self.wideItemIdentifier]
        bar.principalItemIdentifier = Self.wideItemIdentifier
        return bar
    }()

    private var isInstalled = false
    private var isWideBarPresented = false
    private var lastText: String?

    init(appState: AppState, settingsStore: SettingsStore) {
        self.appState = appState
        self.settingsStore = settingsStore

        trayMarquee = TouchBarMarqueeView(
            frame: NSRect(x: 0, y: 0, width: Self.trayWidth, height: Self.itemHeight)
        )
        trayMarquee.preferredWidth = Self.trayWidth
        trayMarquee.text = Self.placeholderText

        wideMarquee = TouchBarMarqueeView(
            frame: NSRect(x: 0, y: 0, width: Self.wideWidth, height: Self.itemHeight)
        )
        wideMarquee.preferredWidth = Self.wideWidth
        wideMarquee.text = Self.placeholderText

        let item = NSCustomTouchBarItem(identifier: Self.trayItemIdentifier)
        item.view = trayMarquee // must be set before addSystemTrayItem:
        item.customizationLabel = "Now Playing Lyrics"
        trayItem = item

        super.init()

        trayMarquee.addGestureRecognizer(
            NSClickGestureRecognizer(target: self, action: #selector(handleTrayTap))
        )

        observe()
    }

    deinit { uninstall() }

    /// Called from `applicationWillTerminate`, so the Touch Bar is left clean even though `deinit`
    /// may not run on quit.
    func tearDown() { uninstall() }

    // MARK: - Wiring

    private func observe() {
        // @Published replays its current value to new subscribers, so this also performs the
        // initial install when the setting was already on at launch.
        settingsStore.$touchBarLyricsEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                enabled ? self?.install() : self?.uninstall()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(appState.$lyricsResult, appState.$currentLineIndex)
            .sink { [weak self] _, _ in self?.refreshText() }
            .store(in: &cancellables)

        // ControlStrip/TouchBarServer are restarted across sleep on some machines, silently
        // dropping third-party tray items. Re-install on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isInstalled else { return }
            self.isInstalled = false
            self.install()
        }
    }

    @objc private func handleTrayTap() {
        guard isInstalled else { return }
        isWideBarPresented ? dismissWideBar() : presentWideBar()
    }

    // MARK: - Install / uninstall

    private func install() {
        guard !isInstalled else { return }
        guard TouchBarPrivateAPI.isControlStripAvailable else {
            NSLog("[TouchBar] Control Strip API unavailable on this macOS; lyrics item skipped.")
            return
        }
        refreshText(force: true)
        guard TouchBarPrivateAPI.addSystemTrayItem(trayItem) else { return }
        TouchBarPrivateAPI.setControlStripPresence(true, for: Self.trayItemIdentifier)
        isInstalled = true
        presentWideBar()
    }

    private func uninstall() {
        guard isInstalled else { return }
        dismissWideBar()
        // Order matters: hide it first, then withdraw the item.
        TouchBarPrivateAPI.setControlStripPresence(false, for: Self.trayItemIdentifier)
        TouchBarPrivateAPI.removeSystemTrayItem(trayItem)
        isInstalled = false
    }

    private func presentWideBar() {
        guard !isWideBarPresented, TouchBarPrivateAPI.isSystemModalAvailable else { return }
        TouchBarPrivateAPI.setSystemModalShowsCloseBox(false)
        // placement 0 keeps the Control Strip beside the presented bar.
        guard TouchBarPrivateAPI.presentSystemModalBar(
            wideBar,
            placement: 0,
            anchoredTo: Self.trayItemIdentifier
        ) else { return }
        isWideBarPresented = true
    }

    private func dismissWideBar() {
        guard isWideBarPresented else { return }
        TouchBarPrivateAPI.dismissSystemModalBar(wideBar)
        isWideBarPresented = false
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == Self.wideItemIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = wideMarquee
        item.customizationLabel = "Now Playing Lyrics"
        return item
    }

    // MARK: - Text

    private var currentLyricText: String {
        guard case .synced(let lines) = appState.lyricsResult else { return Self.placeholderText }
        let index = appState.currentLineIndex ?? 0
        guard lines.indices.contains(index) else { return Self.placeholderText }
        let text = lines[index].text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? Self.placeholderText : text
    }

    /// Deduped here as well as in the view: the playback poller fires several times a second with
    /// the same line, and restarting the scroll animation that often makes it unreadable.
    private func refreshText(force: Bool = false) {
        let text = currentLyricText
        guard force || text != lastText else { return }
        lastText = text
        trayMarquee.text = text
        wideMarquee.text = text
    }
}

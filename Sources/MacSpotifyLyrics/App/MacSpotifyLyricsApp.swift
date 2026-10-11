import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let settingsStore = SettingsStore()
    private var floatingPanel: FloatingPanel?
    private var settingsWindowController: SettingsWindowController?
    private var touchBarController: TouchBarLyricsController?
    private let poller = SpotifyPoller()
    private var lyricsSourceChain: LyricsSourceChain
    private let lyricsCache = LyricsCache()
    private let syncEngine = LyricsSyncEngine()
    private var lastResolvedTrackKey: String?
    private var lyricsGeneration = 0
    private var lyricsFetchTask: Task<Void, Never>?
    // 延迟显示“未检测到歌曲正在播放”的任务，用于吞掉切歌瞬间的短暂空状态
    private var noTrackTask: Task<Void, Never>?
    private var settingsCancellables = Set<AnyCancellable>()

    override init() {
        lyricsSourceChain = LyricsSourceChain(
            providers: LyricsProviderFactory.makeProviders(
                for: settingsStore.lyricsSources
            )
        )
        super.init()
        observeSettings()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = FloatingPanel(
            content: LyricsOverlayView(
                appState: appState,
                settingsStore: settingsStore
            )
        )
        if settingsStore.overlayVisible {
            panel.makeKeyAndOrderFront(nil)
        }
        floatingPanel = panel

        touchBarController = TouchBarLyricsController(
            appState: appState,
            settingsStore: settingsStore
        )

        poller.startPolling { [weak self] snapshot in
            self?.handleSnapshot(snapshot)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController?.tearDown()
        poller.stopPolling()
        lyricsFetchTask?.cancel()
        noTrackTask?.cancel()
        lyricsCache.purgeNotDownloaded()
    }

    private func observeSettings() {
        settingsStore.$lyricsSources
            .dropFirst()
            .sink { [weak self] configs in
                guard let self else { return }
                self.lyricsSourceChain = LyricsSourceChain(
                    providers: LyricsProviderFactory.makeProviders(for: configs)
                )
                //                self.lyricsCache.clear()
                self.lastResolvedTrackKey = nil
                if let snapshot = self.appState.currentSnapshot {
                    self.handleSnapshot(snapshot)
                }
            }
            .store(in: &settingsCancellables)
    }

    private func handleSnapshot(_ snapshot: PlaybackSnapshot?) {
        appState.currentSnapshot = snapshot

        guard let snapshot else {
            // 切歌瞬间 Spotify 会短暂返回空状态，延迟 1s 再提示，避免闪烁
            noTrackTask?.cancel()
            noTrackTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1s
                guard let self, !Task.isCancelled,
                    self.appState.currentSnapshot == nil
                else { return }
                self.lastResolvedTrackKey = nil
                self.lyricsFetchTask?.cancel()
                self.appState.lyricsResult = .plain(
                    "未检测到歌曲正在播放\n\n请运行Spotify并播放一首歌。"
                )
                self.appState.currentLineIndex = nil
            }
            return
        }

        // 歌曲状态恢复，取消可能挂起的“无歌曲”提示
        noTrackTask?.cancel()
        noTrackTask = nil
        
        let trackKey = LyricsCache.trackkKey(
            artist: snapshot.artist,
            title: snapshot.title,
            duration: snapshot.duration,
            album: snapshot.album
        )
        if trackKey != lastResolvedTrackKey {
            lastResolvedTrackKey = trackKey
            resolveLyrics(
                artist: snapshot.artist,
                title: snapshot.title,
                duration: snapshot.duration,
                trackKey: trackKey,
                album: snapshot.album
            )
        }

        if case .synced(let lines) = appState.lyricsResult {
            appState.currentLineIndex = syncEngine.currentLineIndex(
                for: snapshot.position,
                in: lines
            )
        }
    }

    private func resolveLyrics(
        artist: String,
        title: String,
        duration: TimeInterval,
        trackKey: String,
        album: String
    ) {
        lyricsFetchTask?.cancel()
        lyricsGeneration = 1
        let generation = lyricsGeneration
        appState.currentLineIndex = nil

        if let cached = lyricsCache.get(trackKey: trackKey) {
            //            appState.lyricsResult = .plain("匹配到本地歌词")
            //            Task { @MainActor in
            //                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            //                guard !Task.isCancelled, self.lastResolvedTrackKey == trackKey else { return }
            appState.lyricsResult = cached
            //            }
            return
        }

        print("本地没有歌词缓存，联网搜索...")
        appState.lyricsResult = .plain("联网搜索歌词...")

        let chain = lyricsSourceChain
        lyricsFetchTask = Task { [weak self] in
            guard let self else { return }
            let result = await chain.resolve(
                artist: artist,
                title: title,
                duration: duration,
                album: album
            )
            guard !Task.isCancelled else { return }
            //            self.lyricsCache.set(
            //                artist: artist,
            //                title: title,
            //                duration: duration,
            //                album: album,
            //                result: result
            //            )
            //            DispatchQueue.main.async {
            //                // Only apply if the track hasn't changed again while this fetch was in flight.
            //                guard self.lastResolvedTrackKey == trackKey else { return }
            //                self.appState.lyricsResult = result
            //            }
            await MainActor.run {
                guard generation == self.lyricsGeneration,
                    self.lastResolvedTrackKey == trackKey
                else { return }
                self.lyricsCache.set(trackKey: trackKey, result: result)
                self.appState.lyricsResult = result
            }
        }
    }

    func deleteCurrentLyrics() {
        guard let snapshot = appState.currentSnapshot else { return }
        let trackKey = LyricsCache.trackkKey(
            artist: snapshot.artist,
            title: snapshot.title,
            duration: snapshot.duration,
            album: snapshot.album
        )
        lyricsFetchTask?.cancel()
        lyricsGeneration += 1
        lyricsCache.markNotDownloaded(trackKey: trackKey)
        appState.lyricsResult = .plain("当前歌词已删除\n\n下次切回本歌曲时将重新下载。")
        appState.currentLineIndex = nil
    }

    func toggleOverlay() {
        guard let panel = floatingPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            settingsStore.overlayVisible = false
        } else {
            panel.makeKeyAndOrderFront(nil)
            settingsStore.overlayVisible = true
        }
    }

    func openSettings() {
        //kunlun
        //        NSApp.setActivationPolicy(.accessory)

        NSApp.activate(ignoringOtherApps: true)

        if let controller = settingsWindowController {
            controller.window?.makeKeyAndOrderFront(nil)
            return
        }

        let controller = SettingsWindowController(settingsStore: settingsStore)
        { [weak self] in
            self?.floatingPanel?.resetToDefaultFrame()
        }
        controller.showWindow(nil)
        settingsWindowController = controller
    }
}

@main
struct MacSpotifyLyricsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appDelegate.appState,
                settingsStore: appDelegate.settingsStore,
                onToggleOverlay: { appDelegate.toggleOverlay() },
                onOpenSettings: { appDelegate.openSettings() },
                onDeleteCurrentLyrics: { appDelegate.deleteCurrentLyrics() }
            )
        } label: {
            MenuBarLabelView(
                appState: appDelegate.appState,
                settingsStore: appDelegate.settingsStore
            )
        }
    }
}

/// The menu bar's icon/title. Falls back to the app icon when the current-lyric setting is off,
/// no track is playing, or the current line is blank/instrumental — a bare music note is less
/// noisy than an empty title flashing in and out of the menu bar.
private struct MenuBarLabelView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        if settingsStore.menuBarLyricsEnabled, let text = currentLyricText {
            HStack(spacing: 4) {
                Image(systemName: "music.note.list")
                Text(text)
            }
        } else {
            Image(systemName: "music.note.list")
        }
    }

    private var currentLyricText: String? {
        guard case .synced(let lines) = appState.lyricsResult else {
            return nil
        }
        let index = appState.currentLineIndex ?? 0
        guard lines.indices.contains(index) else { return nil }
        let text = lines[index].text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}

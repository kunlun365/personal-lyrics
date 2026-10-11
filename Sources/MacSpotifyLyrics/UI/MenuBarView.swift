import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settingsStore: SettingsStore
    var onToggleOverlay: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onDeleteCurrentLyrics: () -> Void = {}

    var body: some View {
        Button("显示/隐藏 桌面悬浮歌词", action: onToggleOverlay)
        Button("删除当前歌词", action: onDeleteCurrentLyrics).disabled(appState.currentSnapshot == nil)
        Toggle("在菜单栏显示歌词", isOn: $settingsStore.menuBarLyricsEnabled)
        Toggle("在TouchBar显示歌词", isOn: $settingsStore.touchBarLyricsEnabled)
            .disabled(!TouchBarPrivateAPI.isControlStripAvailable)
        Button("设置...", action: onOpenSettings)
        Divider()
        Button("给作者点杯咖啡 ☕") {
            NSWorkspace.shared.open(AppLinks.koFi)
        }
        Divider()
        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}

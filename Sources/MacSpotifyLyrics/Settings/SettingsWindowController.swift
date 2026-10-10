import AppKit
import Combine
import SwiftUI

enum SettingsPane: String, CaseIterable {
    case sources = "歌词源"
    case appearance = "界面外观"

    var symbolName: String {
        switch self {
        case .sources: return "text.quote"
        case .appearance: return "paintbrush"
        }
    }

    var identifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }
}

private final class SettingsWindowState: ObservableObject {
    @Published var selectedPane: SettingsPane = .sources
}

private struct SettingsRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var windowState: SettingsWindowState
    var onResetWindowSize: () -> Void
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch windowState.selectedPane {
                case .sources:
                    LyricsSourcesSettingsView(settingsStore: settingsStore)
                case .appearance:
                    AppearanceSettingsView(settingsStore: settingsStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button {
                    NSWorkspace.shared.open(AppLinks.koFi)
                } label: {
                    Label("支持作者", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(.link)
                .help("歌词精灵是免费的 — 请我喝杯咖啡吧")

                Spacer()

                Button("恢复初始设置...") {
                    showResetConfirmation = true
                }
            }
            .padding(12)
        }
        .frame(width: 480, height: 420)
        .confirmationDialog(
            "确定将所有设定恢复到初始设置？这会移除所有你添加过的自定义歌词源，并还原悬浮歌词区域大小。",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                settingsStore.resetToDefaults()
                onResetWindowSize()
            }
            Button("取消", role: .cancel) {}
        }
    }
}

/// Classic macOS preferences-window chrome: panes switch via toolbar buttons built into the
/// title bar itself (window title updates to the pane name), matching System Settings /
/// System Preferences — not a SwiftUI TabView picker, which renders as a generic segmented
/// control with its own extra title row and doesn't look native on macOS.
///
/// Panes switch via a single, persistent SwiftUI state property (`windowState`), not by
/// replacing `window.contentView` — swapping in a fresh NSHostingView per pane discarded and
/// rebuilt the List's view hierarchy every time, which could leave it blank when returning to
/// a previously-shown pane.
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private let windowState = SettingsWindowState()
    private let toolbar = NSToolbar(identifier: "SettingsToolbar")
    private var cancellable: AnyCancellable?

    init(settingsStore: SettingsStore, onResetWindowSize: @escaping () -> Void)
    {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsRootView(
                settingsStore: settingsStore,
                windowState: windowState,
                onResetWindowSize: onResetWindowSize
            )
        )
        super.init(window: window)

        //kunlun
        //        print("Settings window:", window)
        //        print("Settings canBecomeKey:", window.canBecomeKey)
        //        print("Settings isVisible:", window.isVisible)
        //        print("Activation policy:", NSApp.activationPolicy().rawValue)

        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar
        window.toolbarStyle = .preference

        window.title = windowState.selectedPane.rawValue
        toolbar.selectedItemIdentifier = windowState.selectedPane.identifier

        cancellable = windowState.$selectedPane.sink { [weak self] pane in
            self?.window?.title = pane.rawValue
            self?.toolbar.selectedItemIdentifier = pane.identifier
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectPane(_ sender: NSToolbarItem) {
        guard let pane = SettingsPane(rawValue: sender.itemIdentifier.rawValue)
        else { return }
        windowState.selectedPane = pane
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = SettingsPane(rawValue: itemIdentifier.rawValue) else {
            return nil
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.rawValue
        item.image = NSImage(
            systemSymbolName: pane.symbolName,
            accessibilityDescription: pane.rawValue
        )
        item.target = self
        item.action = #selector(selectPane(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem
        .Identifier]
    {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem
        .Identifier]
    {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar)
        -> [NSToolbarItem.Identifier]
    {
        SettingsPane.allCases.map(\.identifier)
    }
}

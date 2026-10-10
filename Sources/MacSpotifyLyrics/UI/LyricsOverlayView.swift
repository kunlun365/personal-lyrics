import SwiftUI

struct LyricsOverlayView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            trackHeader
            lyricsBody
        }
        .padding(20)
        // Anchored to the top: the header's position never shifts as the lyrics below it grow
        // or shrink (e.g. a line wrapping to more rows) — only the box grows downward.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    settingsStore.backgroundColor.color.opacity(
                        settingsStore.overlayOpacity
                    )
                )
        )
    }

    /// Text size is a fixed, user-controlled setting — resizing the panel changes how much
    /// room the lyrics have, not the glyph size. Other lines/header derive from this.
    private var currentLineSize: CGFloat { CGFloat(settingsStore.textSize) }
    private var nextLineSize: CGFloat { max(9, currentLineSize - 2) }
    private var headerSize: CGFloat { max(10, currentLineSize - 3) }

    /// A nice-to-have single-line strip above the lyrics — kept small and dim so it never
    /// competes with the lyrics for attention or grows the panel. Long titles/artists scroll
    /// instead of wrapping.
    @ViewBuilder
    private var trackHeader: some View {
        if let snapshot = appState.currentSnapshot {
            MarqueeText(
                text: "\(snapshot.title) - \(snapshot.artist)",
                font: appFont(size: headerSize, weight: .medium),
                color: settingsStore.textColor.color.opacity(0.55),
                height: headerSize + 3
            )
        }
    }

    @ViewBuilder
    private var lyricsBody: some View {
        switch appState.lyricsResult {
        case .synced(let lines):
            syncedLines(lines)
        case .plain(let text):
            Text(text)
                .font(appFont(size: currentLineSize - 2, weight: .medium))
                .foregroundStyle(settingsStore.textColor.color)
                .multilineTextAlignment(.center)
        case .none:
            Text("没有搜索到歌词")
                .font(appFont(size: currentLineSize - 2, weight: .regular))
                .foregroundStyle(settingsStore.textColor.color.opacity(0.6))
        }
    }

    /// Current line prominent on top, next line dimmed below. Lines wrap to as many rows as
    /// they need — no truncation — since the header above is anchored independently and won't
    /// shift when these grow. When the current line advances, the outgoing line slides/fades up
    /// and out while the new one slides/fades in from below — a vertical karaoke-style highlight.
    private func syncedLines(_ lines: [LyricLine]) -> some View {
        let index = appState.currentLineIndex ?? 0
        let currentText = lines.indices.contains(index) ? lines[index].text : ""
        let nextText =
            lines.indices.contains(index + 1) ? lines[index + 1].text : ""

        return VStack(spacing: 8) {
            Text(currentText)
                .id(index)
                .font(appFont(size: currentLineSize, weight: .bold))
                .foregroundStyle(settingsStore.textColor.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .transition(lineTransition)

            Text(nextText)
                .id(index + 1)
                .font(appFont(size: nextLineSize, weight: .regular))
                .foregroundStyle(settingsStore.textColor.color.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .transition(lineTransition)
        }
        .animation(.easeInOut(duration: 0.35), value: index)
    }

    private func appFont(size: CGFloat, weight: Font.Weight) -> Font {
        if settingsStore.fontName == "System" {
            return .system(size: size, weight: weight)
        }
        return .custom(settingsStore.fontName, size: size).weight(weight)
    }

    private var lineTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}

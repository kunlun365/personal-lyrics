import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    static let defaultSize = NSSize(width: 420, height: 160)

    init<Content: View>(content: Content) {
        let container = ResizableOverlayView(frame: NSRect(origin: .zero, size: Self.defaultSize))

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Classic autoresizing-mask sizing, not Auto Layout constraints: with constraints,
        // NSHostingView's SwiftUI-driven intrinsic content size can propagate back up and
        // resize the window itself whenever the lyrics content changes (e.g. on every track
        // change) — a feedback loop that silently overrides manual/reset resizing. Autoresizing
        // mask sizing is strictly one-way (container → hosting only), so hosting's intrinsic
        // size can never influence the window's frame.
        let hosting = NSHostingView(rootView: content)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        contentView = container
        minSize = container.minimumSize
        maxSize = container.maximumSize
        center()
    }
    
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Bottom margin used when resetting to the default position, so the panel doesn't sit
    /// flush against the screen edge (or the Dock, if it's on the bottom).
    private static let defaultBottomMargin: CGFloat = 40

    func resetToDefaultFrame() {
        NSApp.activate(ignoringOtherApps: true)

        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        let origin = NSPoint(
            x: screenFrame.midX - Self.defaultSize.width / 2,
            y: screenFrame.minY + Self.defaultBottomMargin
        )
        setFrame(NSRect(origin: origin, size: Self.defaultSize), display: true)
        orderOut(nil)
        makeKeyAndOrderFront(nil)
    }
}

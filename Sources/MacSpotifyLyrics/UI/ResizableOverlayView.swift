import AppKit

/// Hosts the panel's SwiftUI content and adds native-feeling edge/corner drag-to-resize on a
/// borderless window, which draws no system resize chrome of its own. Clicks outside the
/// resize margin fall through to the default NSView behavior, which is what makes
/// `isMovableByWindowBackground` drag-to-move keep working.
final class ResizableOverlayView: NSView {
    struct ResizeEdge: OptionSet {
        let rawValue: Int
        static let left = ResizeEdge(rawValue: 1 << 0)
        static let right = ResizeEdge(rawValue: 1 << 1)
        static let top = ResizeEdge(rawValue: 1 << 2)
        static let bottom = ResizeEdge(rawValue: 1 << 3)
    }

    var minimumSize = NSSize(width: 260, height: 110)
    var maximumSize = NSSize(width: 1200, height: 700)

    private let resizeMargin: CGFloat = 8
    private var activeEdge: ResizeEdge = []
    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartFrame: NSRect = .zero

    /// Without this, the hosting view (a subview covering the full bounds) is always the
    /// deepest hit-tested view, so this container never receives mouse events at all — edges
    /// included. Reclaim just the resize margin for ourselves; everything else still hit-tests
    /// normally into the SwiftUI content/background-drag path.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        if bounds.contains(localPoint), !resizeEdge(at: localPoint).isEmpty {
            return self
        }
        return super.hitTest(point)
    }

    /// macOS only lets the active application control the system cursor — since this app is
    /// deliberately nonactivating (so it doesn't steal focus from Spotify just by being
    /// hovered), no cursor mechanism can show a resize cursor on hover alone. Activating here,
    /// right as an actual resize drag begins, is a deliberate user action (not passive hover),
    /// and makes the cursor update correctly for the duration of the drag.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        activeEdge = resizeEdge(at: point)
        if !activeEdge.isEmpty, let window {
            NSApp.activate(ignoringOtherApps: true)
            cursor(for: activeEdge).set()
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartFrame = window.frame
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !activeEdge.isEmpty, let window else {
            super.mouseDragged(with: event)
            return
        }

        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouseLocation.x
        let dy = current.y - dragStartMouseLocation.y

        var newFrame = dragStartFrame

        if activeEdge.contains(.right) {
            newFrame.size.width = clampedWidth(dragStartFrame.width + dx)
        }
        if activeEdge.contains(.left) {
            let width = clampedWidth(dragStartFrame.width - dx)
            newFrame.origin.x = dragStartFrame.maxX - width
            newFrame.size.width = width
        }
        if activeEdge.contains(.top) {
            newFrame.size.height = clampedHeight(dragStartFrame.height + dy)
        }
        if activeEdge.contains(.bottom) {
            let height = clampedHeight(dragStartFrame.height - dy)
            newFrame.origin.y = dragStartFrame.maxY - height
            newFrame.size.height = height
        }

        window.setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if !activeEdge.isEmpty {
            NSCursor.arrow.set()
        }
        activeEdge = []
        super.mouseUp(with: event)
    }

    private func cursor(for edge: ResizeEdge) -> NSCursor {
        switch edge {
        case [.left], [.right]:
            return .resizeLeftRight
        case [.top], [.bottom]:
            return .resizeUpDown
        case [.left, .top], [.right, .bottom], [.left, .bottom], [.right, .top]:
            return .resizeLeftRight
        default:
            return .arrow
        }
    }

    private func clampedWidth(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumSize.width), maximumSize.width)
    }

    private func clampedHeight(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumSize.height), maximumSize.height)
    }

    private func resizeEdge(at point: NSPoint) -> ResizeEdge {
        var edge: ResizeEdge = []
        if point.x <= resizeMargin { edge.insert(.left) }
        if point.x >= bounds.width - resizeMargin { edge.insert(.right) }
        if point.y <= resizeMargin { edge.insert(.bottom) }
        if point.y >= bounds.height - resizeMargin { edge.insert(.top) }
        return edge
    }
}

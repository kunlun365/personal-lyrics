import AppKit

/// A single-line ticker for the Touch Bar Control Strip: centers text that fits, and loops it
/// horizontally when it doesn't.
///
/// This is deliberately Core Animation rather than the SwiftUI `MarqueeText` used by the overlay.
/// The Touch Bar renders out of process, and a SwiftUI `repeatForever` animation driven per-frame
/// by the app stutters and restarts across that boundary. A `CABasicAnimation` is handed to the
/// render server once and animates independently of the app, so it stays smooth.
final class TouchBarMarqueeView: NSView {
    private static let gap: CGFloat = 40          // blank run between the two copies, in points
    private static let speed: CGFloat = 30        // points per second
    private static let animationKey = "marquee.scroll"

    private let textLayer = CATextLayer()
    private let font = NSFont.systemFont(ofSize: 15, weight: .medium)

    /// Assigning the same string twice is a no-op, so the scroll never restarts mid-line.
    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            rebuild()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.truncationMode = .none
        textLayer.isWrapped = false
        layer?.addSublayer(textLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The Control Strip sizes tray items from their intrinsic content size; a width constraint
    /// alone gets ignored and the item collapses to a standard button-sized slot.
    var preferredWidth: CGFloat = 700 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: bounds.height > 0 ? bounds.height : 30)
    }

    /// Only rebuild when the width genuinely changed. The Touch Bar re-lays-out its items
    /// frequently, and rebuilding on every pass would restart the scroll and reintroduce the
    /// stutter this view exists to avoid.
    private var lastBuiltWidth: CGFloat = -1

    override func layout() {
        super.layout()
        guard bounds.width != lastBuiltWidth else { return }
        rebuild()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        textLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func width(of string: String) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
    }

    private func rebuild() {
        guard bounds.width > 0 else { return }
        lastBuiltWidth = bounds.width

        // Frame and content changes must not pick up implicit animations — only the explicit
        // scroll animation below should move anything.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        textLayer.removeAnimation(forKey: Self.animationKey)

        let lineHeight = font.ascender - font.descender
        let originY = ((bounds.height - lineHeight) / 2).rounded()
        let singleWidth = width(of: text)

        guard singleWidth > bounds.width else {
            // Fits: center it and leave it still.
            textLayer.string = text
            textLayer.alignmentMode = .center
            textLayer.frame = CGRect(x: 0, y: originY, width: bounds.width, height: lineHeight)
            return
        }

        // Doesn't fit: lay out two copies separated by a gap and translate by exactly one
        // copy-plus-gap, so the loop point is seamless.
        let spacer = String(repeating: " ", count: 1)
        let spacerWidth = width(of: spacer)
        let gapRun = max(1, Int((Self.gap / max(spacerWidth, 1)).rounded()))
        let looped = text + String(repeating: " ", count: gapRun) + text
        let cycleWidth = singleWidth + CGFloat(gapRun) * spacerWidth

        textLayer.string = looped
        textLayer.alignmentMode = .left
        textLayer.frame = CGRect(x: 0, y: originY, width: width(of: looped), height: lineHeight)

        let scroll = CABasicAnimation(keyPath: "transform.translation.x")
        scroll.fromValue = 0
        scroll.toValue = -cycleWidth
        scroll.duration = CFTimeInterval(cycleWidth / Self.speed)
        scroll.repeatCount = .infinity
        scroll.timingFunction = CAMediaTimingFunction(name: .linear)
        scroll.isRemovedOnCompletion = false
        textLayer.add(scroll, forKey: Self.animationKey)
    }
}

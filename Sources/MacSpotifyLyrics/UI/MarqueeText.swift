import SwiftUI

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A single-line text view that scrolls horizontally (ticker-style) when its content is wider
/// than the available space, instead of wrapping to multiple lines or truncating. Used for
/// track title/artist so long metadata never grows the panel or crowds the lyrics.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 12, weight: .medium)
    var color: Color = .white.opacity(0.7)
    var height: CGFloat = 16
    var speed: Double = 28 // points per second
    var gap: CGFloat = 32

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            content
                .onAppear { containerWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { containerWidth = $0 }
        }
        .frame(height: height)
        .clipped()
        .background(measurementText)
        .onChange(of: textWidth) { _ in restartAnimationIfNeeded() }
        .onChange(of: containerWidth) { _ in restartAnimationIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if needsScrolling {
            HStack(spacing: gap) {
                Text(text).fixedSize()
                Text(text).fixedSize()
            }
            .font(font)
            .foregroundStyle(color)
            .offset(x: offset)
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var measurementText: some View {
        Text(text)
            .font(font)
            .fixedSize()
            .opacity(0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(WidthPreferenceKey.self) { textWidth = $0 }
            .allowsHitTesting(false)
    }

    private var needsScrolling: Bool {
        containerWidth > 0 && textWidth > containerWidth
    }

    private func restartAnimationIfNeeded() {
        guard needsScrolling else {
            offset = 0
            return
        }
        offset = 0
        withAnimation(.linear(duration: Double(textWidth + gap) / speed).repeatForever(autoreverses: false)) {
            offset = -(textWidth + gap)
        }
    }
}

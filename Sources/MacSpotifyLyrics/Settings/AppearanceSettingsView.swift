import SwiftUI
import AppKit

struct AppearanceSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    private static let fontFamilies: [String] = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("悬浮窗背景透明度")
                        Spacer()
                        Text("\(Int(settingsStore.overlayOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settingsStore.overlayOpacity, in: 0.1...1.0)
                }

                ColorPicker("背景颜色", selection: backgroundColorBinding, supportsOpacity: false)
                ColorPicker("文字颜色", selection: textColorBinding, supportsOpacity: false)

                Picker("字体", selection: $settingsStore.fontName) {
                    ForEach(Self.fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("字号")
                        Spacer()
                        Text("\(Int(settingsStore.textSize))pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settingsStore.textSize, in: 12...32, step: 1)
                }
            }
        }
        .padding(20)
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { settingsStore.backgroundColor.color },
            set: { settingsStore.backgroundColor = CodableColor(color: $0) }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { settingsStore.textColor.color },
            set: { settingsStore.textColor = CodableColor(color: $0) }
        )
    }
}

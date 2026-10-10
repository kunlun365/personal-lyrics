import SwiftUI

/// Standard macOS modal-sheet pattern (title, form, Cancel/default-action buttons)
/// for adding a user-supplied lyrics source.
struct AddLyricsSourceSheet: View {
    @ObservedObject var settingsStore: SettingsStore
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var urlTemplate = ""
    @State private var apiKeyHeader = ""
    @State private var apiKeyValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加自定义歌词源")
                .font(.headline)

            Form {
                TextField("助记名", text: $name)
                TextField("歌词源地址模板", text: $urlTemplate, prompt: Text("https://example.com/lyrics?artist={artist}&title={title}"))
                TextField("API Key Header (可选)", text: $apiKeyHeader)
                SecureField("API Key Value (可选)", text: $apiKeyValue)
            }

            Text("使用 {artist}, {title}, {duration} 作为占位符。你的任何输入都将只在这台电脑本地存储，或者只会发送给以上歌词源云端地址。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("添加") {
                    add()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || urlTemplate.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func add() {
        let config = LyricsSourceConfig(
            kind: .customURL,
            name: name,
            urlTemplate: urlTemplate,
            apiKeyHeaderName: apiKeyHeader.isEmpty ? nil : apiKeyHeader,
            apiKeyValue: apiKeyValue.isEmpty ? nil : apiKeyValue,
            isEnabled: true
        )
        settingsStore.lyricsSources.append(config)
        isPresented = false
    }
}

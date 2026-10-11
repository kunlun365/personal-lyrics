import SwiftUI

/// Standard macOS modal-sheet pattern (title, form, Cancel/default-action buttons)
/// for adding a user-supplied lyrics source.
struct AddLyricsSourceSheet: View {
    @ObservedObject var settingsStore: SettingsStore
    @Binding var isPresented: Bool
    var editingSource: LyricsSourceConfig?

    @State private var name = ""
    @State private var urlTemplate = ""
    @State private var apiKeyHeader = ""
    @State private var apiKeyValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "编辑自定义歌词源" : "添加自定义歌词源")
                .font(.headline)

            Form {
                TextField("助记名", text: $name)
                TextField(
                    "歌词源地址模板",
                    text: $urlTemplate,
                    prompt: Text(
                        "https://example.com/lyrics?artist={artist}&title={title}"
                    )
                )
                TextField("API Key Header (可选)", text: $apiKeyHeader)
                SecureField("API Key Value (可选)", text: $apiKeyValue)
            }

            Text(
                "使用 {artist}, {title}, {album}, {duration} 作为占位符。你的任何输入都将只在这台电脑本地存储，或者只会发送给以上歌词源云端地址。"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "保存" : "添加") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    name.trimmingCharacters(in: .whitespaces).isEmpty
                        || urlTemplate.trimmingCharacters(in: .whitespaces)
                            .isEmpty
                )
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let source = editingSource {
                name = source.name
                urlTemplate = source.urlTemplate ?? ""
                apiKeyHeader = source.apiKeyHeaderName ?? ""
                apiKeyValue = source.apiKeyValue ?? ""
            }
        }
    }
    
    private var isEditing: Bool { editingSource != nil }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedTemplate = urlTemplate.trimmingCharacters(in: .whitespaces)

        if isEditing, let source = editingSource,
            let idx = settingsStore.lyricsSources.firstIndex(where: {
                $0.id == source.id
            })
        {
            settingsStore.lyricsSources[idx].name = trimmedName
            settingsStore.lyricsSources[idx].urlTemplate = trimmedTemplate
            settingsStore.lyricsSources[idx].apiKeyHeaderName =
                apiKeyHeader.isEmpty ? nil : apiKeyHeader
            settingsStore.lyricsSources[idx].apiKeyValue =
                apiKeyValue.isEmpty ? nil : apiKeyValue
        } else {
            let config = LyricsSourceConfig(
                kind: .customURL,
                name: trimmedName,
                urlTemplate: trimmedTemplate,
                apiKeyHeaderName: apiKeyHeader.isEmpty ? nil : apiKeyHeader,
                apiKeyValue: apiKeyValue.isEmpty ? nil : apiKeyValue,
                isEnabled: true
            )
            settingsStore.lyricsSources.append(config)
        }
        isPresented = false
    }
}

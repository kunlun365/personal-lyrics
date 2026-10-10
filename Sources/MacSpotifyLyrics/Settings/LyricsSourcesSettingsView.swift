import SwiftUI

struct LyricsSourcesSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var isAddingSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("下方列表的歌词源会逐个尝试，第一个匹配成功的用于歌词显示。拖动可以排序。")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(settingsStore.lyricsSources) { source in
                    LyricsSourceRow(source: source, settingsStore: settingsStore)
                }
                .onMove { indices, newOffset in
                    settingsStore.lyricsSources.move(fromOffsets: indices, toOffset: newOffset)
                }
                .onDelete { indices in
                    settingsStore.lyricsSources.remove(atOffsets: indices)
                }
            }
            .listStyle(.inset)

            HStack {
                Spacer()
                Button {
                    isAddingSource = true
                } label: {
                    Label("添加源...", systemImage: "plus")
                }
            }
        }
        .padding(20)
        .sheet(isPresented: $isAddingSource) {
            AddLyricsSourceSheet(settingsStore: settingsStore, isPresented: $isAddingSource)
        }
    }
}

private struct LyricsSourceRow: View {
    let source: LyricsSourceConfig
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.kind == .lrclib ? "music.quarternote.3" : "link")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                if source.kind == .customURL, let template = source.urlTemplate {
                    Text(template)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Toggle("", isOn: enabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()

            Button {
                settingsStore.lyricsSources.removeAll { $0.id == source.id }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { source.isEnabled },
            set: { newValue in
                guard let idx = settingsStore.lyricsSources.firstIndex(where: { $0.id == source.id }) else { return }
                settingsStore.lyricsSources[idx].isEnabled = newValue
            }
        )
    }
}

import Foundation

final class AppState: ObservableObject {
    @Published var currentSnapshot: PlaybackSnapshot?
    @Published var lyricsResult: LyricsResult = .plain("没有歌曲正在播放\n\n歌词程序正在值守中。")
    @Published var currentLineIndex: Int?
}

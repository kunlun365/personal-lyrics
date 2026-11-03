//  通用
//
//  Created by Andy on 2026/11/3.
//

import Foundation

final class MediaRemoteAdapterPoller {
    private var process: Process?
    private var outputPipe: Pipe?
    private var timer: Timer?
    private var shouldRun = false

    private var buffer = Data()
    private var latest: TrackState?
    private var onUpdateHandler: ((PlaybackSnapshot?) -> Void)?

    private var lastEmitted: PlaybackSnapshot?
    private var lastEmittedKey: String?
    private var lastEmittedNil = false

    private struct TrackState {
        let key: String
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
        var elapsed: TimeInterval
        let timestamp: TimeInterval  // epoch 秒；0 表示缺失
        var rate: Double
        var isPlaying: Bool
        let anchorNow: Bool  // 暂停→播放时用“现在”做基准
        let receivedAt: Date
    }

    func startPolling(
        interval: TimeInterval = 0.25,
        onUpdate: @escaping (PlaybackSnapshot?) -> Void
    ) {
        onUpdateHandler = onUpdate
        shouldRun = true
        lastEmitted = nil
        lastEmittedKey = nil
        lastEmittedNil = false
        launch()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.emitSnapshot()
        }
    }

    func stopPolling() {
        shouldRun = false
        timer?.invalidate()
        timer = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        onUpdateHandler = nil
        latest = nil
        lastEmitted = nil
        lastEmittedKey = nil
        lastEmittedNil = false
    }

    // 启动 perl + adapter stream

    private func launch() {
        guard shouldRun else { return }

        guard
            let script = Bundle.module.url(
                forResource: "mediaremote-adapter",
                withExtension: "pl"
            ),
            let framework = Bundle.module.url(
                forResource: "MediaRemoteAdapter",
                withExtension: "framework"
            )
        else {
            print("[Adapter] 资源未找到")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            script.path,
            framework.path,
            "stream",
            "--micros",
            "--no-diff",
            "--no-artwork",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = {
            [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consume(data)
            }
        }

        process.terminationHandler = {
            [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.shouldRun else { return }
                self.process = nil
                self.outputPipe = nil
                self.latest = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.launch()
                }
            }
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = pipe
        } catch {
            print("[Adapter] perl 启动失败", error)
        }
    }

    // 解析 stream 输出

    private func consume(_ data: Data) {
        buffer.append(data)

        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = Data(buffer[..<newline])
            buffer.removeSubrange(buffer.startIndex...newline)

            guard !lineData.isEmpty,
                let object = try? JSONSerialization.jsonObject(with: lineData)
                    as? [String: Any],
                let payload = object["payload"] as? [String: Any]
            else { continue }

            apply(payload: payload)
        }
    }

    private func apply(payload: [String: Any]) {
        // payload 为空字典 表示 当前没有播放器在报告歌曲
        guard let title = payload["title"] as? String,
            !title.isEmpty,
            let artist = payload["artist"] as? String,
            !artist.isEmpty
        else {
            latest = nil
            return
        }

        let album = payload["album"] as? String ?? ""
        let duration = Self.seconds(payload["durationMicros"])
        let elapsed = Self.seconds(payload["elapsedTimeMicros"])
        let timestamp = Self.seconds(payload["timestampEpochMicros"])

        let playing = payload["playing"] as? Bool ?? false
        let rawRate = (payload["playbackRate"] as? NSNumber)?.doubleValue ?? 1
        let rate = playing ? (rawRate > 0 ? rawRate : 1) : 0

        let key = "\(title)\u{1}\(artist)\u{1}\(album)\u{1}\(Int(duration))"
        let now = Date()

        let justResumed = (latest?.isPlaying == false) && playing

        latest = TrackState(
            key: key,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: elapsed,
            timestamp: timestamp,
            rate: rate,
            isPlaying: playing,
            anchorNow: justResumed,
            receivedAt: now
        )
    }

    private func emitSnapshot() {
        guard let state = latest else {
            if !lastEmittedNil {
                lastEmittedNil = true
                lastEmitted = nil
                lastEmittedKey = nil
                onUpdateHandler?(nil)
            }
            return
        }
        lastEmittedNil = false

        let now = Date().timeIntervalSince1970

        let reference: TimeInterval
        if state.anchorNow {
            // 恢复播放：以“现在”为锚点，elapsed 取暂停时的位置，不能把暂停的时间也算进播放进度
            reference = now
        } else if state.timestamp > 0 {
            // 正常播放/首次启动：用数据本身的记录时刻外推
            reference = state.timestamp
        } else {
            reference = state.receivedAt.timeIntervalSince1970
        }

        var position =
            state.elapsed + max(0, now - reference) * max(state.rate, 0)
        if state.duration > 0 { position = min(position, state.duration) }
        position = max(position, 0)

        let snapshot = PlaybackSnapshot(
            title: state.title,
            artist: state.artist,
            album: state.album,
            duration: state.duration,
            position: position,
            isPlaying: state.isPlaying
        )

        // 同一首歌、同一播放状态、进度几乎没变化，不回调
        if state.key == lastEmittedKey,
            let last = lastEmitted,
            last.title == snapshot.title,
            last.artist == snapshot.artist,
            last.album == snapshot.album,
            last.duration == snapshot.duration,
            last.isPlaying == snapshot.isPlaying,
            abs(last.position - snapshot.position) < 0.05
        {
            return
        }

        lastEmittedKey = state.key
        lastEmitted = snapshot
        onUpdateHandler?(snapshot)
    }

    private static func seconds(_ value: Any?) -> TimeInterval {
        guard let n = value as? NSNumber else { return 0 }
        return n.doubleValue / 1_000_000
    }

    private static func number(_ value: Any?) -> Double {
        if let n = value as? NSNumber { return n.doubleValue }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return 0
    }

}

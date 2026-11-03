//  通用
//
//  Created by Andy on 2026/11/3.
//

import Darwin
import Foundation

final class MediaRemotePoller {
    private var timer: Timer?
    private var controller: NSObject?

    private var lastTrackKey: String?
    private var lastElapsed: TimeInterval = 0
    private var lastSampleDate = Date()

    // macOS 15.4+ 需要 dlopen，否则 NSClassFromString 找不到 MediaRemote 的类
    private static let mediaRemoteLoaded: Bool = {
        dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW | RTLD_GLOBAL
        ) != nil
    }()

    func startPolling(
        interval: TimeInterval = 0.25,
        onUpdate: @escaping (PlaybackSnapshot?) -> Void
    ) {
        timer?.invalidate()
        poll(onUpdate: onUpdate)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true)
        { [weak self] _ in
            self?.poll(onUpdate: onUpdate)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        _ = controller?.perform(NSSelectorFromString("endLoadingUpdates"))
        controller = nil
        lastTrackKey = nil
    }

    //    private func poll(onUpdate: @escaping (PlaybackSnapshot?) -> Void) {
    //        guard let info = currentInfo() else {
    //            lastTrackKey = nil
    //            onUpdate(nil)
    //            return
    //        }
    //        onUpdate(makeSnapshot(from: info))
    //    }

    private func poll(onUpdate: @escaping (PlaybackSnapshot?) -> Void) {
        let bLoaded = Self.mediaRemoteLoaded
        let bDest = NSClassFromString("MRDestination") != nil
        let bConfig =
            NSClassFromString("MRNowPlayingControllerConfiguration") != nil
        let bCtrl = NSClassFromString("MRNowPlayingController") != nil
        let bResponse = controller?.value(forKey: "response") != nil
        print(
            "加载成功=\(bLoaded) 目标函数链接成功=\(bDest) 配置函数链接成功=\(bConfig) 控制器链接成功=\(bCtrl) 控制器=\(controller != nil) 响应=\(bResponse) 当前播放：",
            currentInfo() ?? [:]
        )

        guard let info = currentInfo() else {
            lastTrackKey = nil
            onUpdate(nil)
            return
        }
        onUpdate(makeSnapshot(from: info))
    }

    // 通过 OC runtime 读取 MRNowPlayingController

    private func currentInfo() -> [String: Any]? {
        guard Self.mediaRemoteLoaded else { return nil }
        ensureController()
        guard let response = controller?.value(forKey: "response") as? NSObject
        else { return nil }
        return Self.makeInfo(from: response)
    }

    private func ensureController() {
        guard controller == nil else { return }

        guard
            let dest = Self.callClassMethod(
                "MRDestination",
                "userSelectedDestination"
            ) as? NSObject,
            let configClass = NSClassFromString(
                "MRNowPlayingControllerConfiguration"
            ),
            let allocatedConfig = Self.allocate(configClass),
            let config =
                allocatedConfig
                .perform(
                    NSSelectorFromString("initWithDestination:"),
                    with: dest
                )?
                .takeUnretainedValue() as? NSObject
        else { return }

        config.setValue(false, forKey: "singleShot")
        config.setValue(true, forKey: "requestPlaybackState")
        config.setValue(true, forKey: "requestPlaybackQueue")

        guard let controllerClass = NSClassFromString("MRNowPlayingController"),
            let rawController = Self.allocate(controllerClass),
            let newController =
                rawController
                .perform(
                    NSSelectorFromString("initWithConfiguration:"),
                    with: config
                )?
                .takeUnretainedValue() as? NSObject
        else { return }

        _ = newController.perform(NSSelectorFromString("beginLoadingUpdates"))
        controller = newController
    }

    //    private func ensureController() {
    //        guard controller == nil else { return }
    //
    //        guard
    //            let dest = Self.callClassMethod(
    //                "MRDestination",
    //                "userSelectedDestination"
    //            )
    //        else {
    //            print("空1")
    //            return
    //        }
    //        print("1是", dest)
    //
    //        guard
    //            let configClass = NSClassFromString(
    //                "MRNowPlayingControllerConfiguration"
    //            )
    //        else {
    //            print("空2")
    //            return
    //        }
    //        guard let allocatedConfig = Self.allocate(configClass) else {
    //            print("空3")
    //            return
    //        }
    //        print("2|3是", allocatedConfig)
    //
    //        guard
    //            let config =
    //                allocatedConfig
    //                .perform(
    //                    NSSelectorFromString("initWithDestination:"),
    //                    with: dest
    //                )?
    //                .takeUnretainedValue() as? NSObject
    //        else {
    //            print("空4")
    //            return
    //        }
    //        print("4是", config)
    //
    //        config.setValue(false, forKey: "singleShot")
    //        config.setValue(true, forKey: "requestPlaybackState")
    //        config.setValue(true, forKey: "requestPlaybackQueue")
    //
    //        guard let controllerClass = NSClassFromString("MRNowPlayingController")
    //        else {
    //            print("空5")
    //            return
    //        }
    //        guard let rawController = Self.allocate(controllerClass) else {
    //            print("空6")
    //            return
    //        }
    //        print("5|6是", rawController)
    //
    //        guard
    //            let newController =
    //                rawController
    //                .perform(
    //                    NSSelectorFromString("initWithConfiguration:"),
    //                    with: config
    //                )?
    //                .takeUnretainedValue() as? NSObject
    //        else {
    //            print("空7")
    //            return
    //        }
    //        print("7是", newController)
    //
    //        _ = newController.perform(NSSelectorFromString("beginLoadingUpdates"))
    //        controller = newController
    //    }

    // 调用 OC 类方法（Swift 的 AnyClass 没有 perform）
    private static func callClassMethod(
        _ className: String,
        _ selectorName: String
    ) -> AnyObject? {
        guard let cls = NSClassFromString(className) else { return nil }
        let sel = NSSelectorFromString(selectorName)
        guard let method = class_getClassMethod(cls, sel) else { return nil }

        typealias Fn = @convention(c) (AnyClass, Selector) -> Unmanaged<
            AnyObject
        >?
        let fn = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        return fn(cls, sel)?.takeUnretainedValue()
    }

    // alloc 返回 +1 对象，所以用 takeRetainedValue
    private static func allocate(_ cls: AnyClass) -> NSObject? {
        let sel = NSSelectorFromString("alloc")
        guard let method = class_getClassMethod(cls, sel) else { return nil }

        typealias Fn = @convention(c) (AnyClass, Selector) -> Unmanaged<
            AnyObject
        >?
        return unsafeBitCast(method_getImplementation(method), to: Fn.self)(
            cls,
            sel
        )?
        .takeRetainedValue() as? NSObject
    }

    private static func makeInfo(from response: NSObject) -> [String: Any]? {
        var info: [String: Any] = [:]

        if let state = response.value(forKey: "playbackState") as? NSNumber {
            info["bridgePlaybackState"] = state
        }
        if let rate = response.value(forKey: "playbackRate") as? NSNumber {
            info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] = rate
        }

        guard let queue = response.value(forKey: "playbackQueue") as? NSObject,
            let items = queue.value(forKey: "contentItems") as? [NSObject],
            !items.isEmpty
        else {
            return info.isEmpty ? nil : info
        }

        let location =
            (queue.value(forKey: "location") as? NSNumber)?.intValue ?? 0
        let item = items.indices.contains(location) ? items[location] : items[0]

        guard let meta = item.value(forKey: "metadata") as? NSObject else {
            return info.isEmpty ? nil : info
        }

        let pairs = [
            ("title", "kMRMediaRemoteNowPlayingInfoTitle"),
            ("trackArtistName", "kMRMediaRemoteNowPlayingInfoArtist"),
            ("albumName", "kMRMediaRemoteNowPlayingInfoAlbum"),
            ("duration", "kMRMediaRemoteNowPlayingInfoDuration"),
            ("elapsedTime", "kMRMediaRemoteNowPlayingInfoElapsedTime"),
        ]
        for (metaKey, infoKey) in pairs {
            if let value = meta.value(forKey: metaKey) {
                info[infoKey] = value
            }
        }

        if let extra = meta.value(forKey: "nowPlayingInfo") as? [String: Any] {
            for (key, value) in extra where info[key] == nil {
                info[key] = value
            }
        }
        return info.isEmpty ? nil : info
    }

    // 转成 PlaybackSnapshot

    private func makeSnapshot(from info: [String: Any]) -> PlaybackSnapshot? {
        if let state = info["bridgePlaybackState"] as? NSNumber,
            state.intValue == 3
        {
            return nil  // stopped
        }

        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
            !title.isEmpty,
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String,
            !artist.isEmpty
        else { return nil }

        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let duration =
            (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?
            .doubleValue ?? 0
        let elapsed =
            (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?
            .doubleValue ?? 0
        let rate =
            (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?
            .doubleValue ?? 0
        let state = (info["bridgePlaybackState"] as? NSNumber)?.intValue

        // elapsedTime 只在事件时刷新，这里按速率插值，歌词才跟得上
        let key = "\(title)\u{1}\(artist)\u{1}\(album)\u{1}\(Int(duration))"
        let now = Date()
        if key != lastTrackKey {
            lastTrackKey = key
            lastElapsed = elapsed
            lastSampleDate = now
        } else if abs(elapsed - lastElapsed) > 0.05 {
            lastElapsed = elapsed
            lastSampleDate = now
        }

        var position =
            lastElapsed + now.timeIntervalSince(lastSampleDate) * max(rate, 0)
        if duration > 0 { position = min(position, duration) }
        position = max(position, 0)

        return PlaybackSnapshot(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: state.map { $0 == 1 } ?? (rate > 0)
        )
    }
}

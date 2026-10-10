import Foundation

/// Polls the local Spotify desktop app for playback state via AppleScript.
final class SpotifyPoller {
    private var timer: Timer?
    private let scriptQueue = DispatchQueue(label: "SpotifyPoller.applescript")
    private let script = NSAppleScript(source: SpotifyPoller.scriptSource)

    func startPolling(interval: TimeInterval = 0.25, onUpdate: @escaping (PlaybackSnapshot?) -> Void) {
        timer?.invalidate()
        poll(onUpdate: onUpdate)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll(onUpdate: onUpdate)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func poll(onUpdate: @escaping (PlaybackSnapshot?) -> Void) {
        guard let script else {
            onUpdate(nil)
            return
        }
        scriptQueue.async {
            var errorDict: NSDictionary?
            let result = script.executeAndReturnError(&errorDict)
            let snapshot = Self.parseSnapshot(from: result)
            DispatchQueue.main.async {
                onUpdate(snapshot)
            }
        }
    }

    /// Fields are joined with \u{1} (not a character that can appear in a track/artist name).
    /// `duration of current track` is in milliseconds; `player position` is in seconds.
    private static let scriptSource = """
    if application "Spotify" is running then
        tell application "Spotify"
            if player state is stopped then
                return "STOPPED"
            end if
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set albumName to album of current track
                set trackDurationMs to duration of current track
                set trackPosition to player position
                set stateStr to player state as string
                return trackName & "\u{1}" & trackArtist & "\u{1}" & albumName & "\u{1}" & (trackDurationMs as string) & "\u{1}" & (trackPosition as string) & "\u{1}" & stateStr
            on error
                return "NO_TRACK"
            end try
        end tell
    else
        return "NOT_RUNNING"
    end if
    """

    private static func parseSnapshot(from descriptor: NSAppleEventDescriptor) -> PlaybackSnapshot? {
        guard let raw = descriptor.stringValue else { return nil }
        switch raw {
        case "NOT_RUNNING", "STOPPED", "NO_TRACK":
            return nil
        default:
            let parts = raw.components(separatedBy: "\u{1}")
            guard parts.count == 6,
                  let durationMs = Double(parts[3]),
                  let position = Double(parts[4]) else {
                return nil
            }
            return PlaybackSnapshot(
                title: parts[0],
                artist: parts[1],
                album: parts[2],
                duration: durationMs / 1000.0,
                position: position,
                isPlaying: parts[5] == "playing"
            )
        }
    }
}

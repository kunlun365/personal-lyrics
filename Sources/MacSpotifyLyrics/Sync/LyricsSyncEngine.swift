import Foundation

final class LyricsSyncEngine {
    /// Returns the index of the last line whose timestamp is <= elapsed, or nil if none.
    func currentLineIndex(for elapsed: TimeInterval, in lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty else { return nil }

        var low = 0
        var high = lines.count - 1
        var result: Int? = nil

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].timestamp <= elapsed {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }
}

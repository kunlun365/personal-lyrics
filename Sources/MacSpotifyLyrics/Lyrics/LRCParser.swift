import Foundation

/// Parses LRC-format lyrics, e.g. lines like "[01:23.45]Some lyric text".
enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine]? {
        guard let regex = try? NSRegularExpression(pattern: #"^\[(\d{2}):(\d{2}(?:\.\d{1,3})?)\](.*)$"#) else {
            return nil
        }

        var lines: [LyricLine] = []
        for rawLine in lrc.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: fullRange),
                  let minutesRange = Range(match.range(at: 1), in: line),
                  let secondsRange = Range(match.range(at: 2), in: line),
                  let textRange = Range(match.range(at: 3), in: line),
                  let minutes = Double(line[minutesRange]),
                  let seconds = Double(line[secondsRange]) else {
                continue
            }

            let text = line[textRange].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            lines.append(LyricLine(timestamp: minutes * 60 + seconds, text: text))
        }
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}

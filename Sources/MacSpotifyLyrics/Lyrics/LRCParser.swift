import Foundation

/// Parses LRC-format lyrics, e.g. lines like "[01:23.45]Some lyric text" or "[02:34.56][01:23.45]Some lyric text".
enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine]? {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2}(?:\.\d{1,3})?)\]"#) else {
            return nil
        }

        var lines: [LyricLine] = []
        for rawLine in lrc.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: fullRange)
            
//            print("DEBUG patern: \(regex.pattern)")
//            print("DEBUG line: \(line)")
//            print("DEBUG matches count: \(matches.count)")
            
            guard !matches.isEmpty else { continue } // 没有时间戳的行（包括元数据行等）直接跳过
            guard let lastMatch = matches.last,
                  let lastRange = Range(lastMatch.range, in: line) else { continue }
            let text = line[lastRange.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            
            // 一行有多个时间戳，每个时间戳都生成同一条歌词
            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: line),
                      let secondsRange = Range(match.range(at: 2), in: line),
                      let minutes = Double(line[minutesRange]),
                      let seconds = Double(line[secondsRange]) else { continue }
                lines.append(LyricLine(timestamp: minutes * 60 + seconds, text: text))
            }
        }
        return lines.sorted { $0.timestamp < $1.timestamp } // 按时间戳排序
    }
}

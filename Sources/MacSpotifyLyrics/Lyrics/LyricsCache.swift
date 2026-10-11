import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

/// TODO: add disk-backed persistence.
final class LyricsCache {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "MacSpotifyLyrics.LyricsCache")

    init() {
        queue.sync { openDatabase() }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    static func trackkKey(
        artist: String,
        title: String,
        duration: TimeInterval,
        album: String
    ) -> String {
        "\(artist)|\(title)|\(duration)|\(album)"
    }

    private func openDatabase() {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("MacSpotifyLyrics", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let path = dir.appendingPathComponent("lyrics_cache.db").path
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            print("无法打开歌词缓存数据库：\(path)")
            sqlite3_close(db)
            db = nil
            return
        }
        sqlite3_exec(
            db,
            """
            CREATE TABLE IF NOT EXISTS lyrics (
                track_key TEXT PRIMARY KEY,
                payload TEXT NOT NULL DEFAULT '',
                downloaded INTEGER NOT NULL DEFAULT 0,
                updated_at REAL NOT NULL
            );
            """,
            nil,
            nil,
            nil
        )
    }

    func get(trackKey: String) -> LyricsResult? {
        queue.sync {
            guard let db else { return nil }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "select payload from lyrics where track_key = ?1 and downloaded = 1", -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, trackKey, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW, let cString = sqlite3_column_text(stmt, 0) else { return nil }
            guard let data = String(cString: cString).data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(LyricsResult.self, from: data)
        }
    }

    func set(
        trackKey: String,
        result: LyricsResult
    ) {
        queue.sync {
            guard let db else { return }
            let downloaded = result != .none
            var payload = ""
            if downloaded, let data = try? JSONEncoder().encode(result) {
                payload = String(data: data, encoding: .utf8) ?? ""
            }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, """
                    insert into lyrics (track_key, payload, downloaded, updated_at)
                    values (?1, ?2, ?3, ?4)
                    on CONFLICT(track_key) DO UPDATE SET
                        payload = excluded.payload,
                        downloaded = excluded.downloaded,
                        updated_at = excluded.updated_at
                    """, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, trackKey, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, payload, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, downloaded ? 1 : 0)
            sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
        }
    }

    func markNotDownloaded(trackKey: String) {
        queue.sync {
            guard let db else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "update lyrics set payload = '', downloaded = 0, updated_at = ?2 where track_key = ?1", -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, trackKey, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            sqlite3_step(stmt)
        }
    }
    
    func purgeNotDownloaded() {
        queue.sync {
            guard let db else { return }
            sqlite3_exec(db, "delete from lyrics where downloaded = 0", nil, nil, nil)
        }
    }
}

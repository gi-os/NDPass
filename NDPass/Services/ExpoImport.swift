import Foundation
import SwiftData
import SQLite3
import UserNotifications

/// Brings over what the Expo version of NDPass left on the phone: the tickets and both keys
/// from `Documents/SQLite/ndpass_v2.db`, and the stub photos from `Documents/tickets/`.
/// An App Store update keeps the app's files, so all of it is still there. Runs once; the old
/// database is left in place, untouched.
enum ExpoImport {
    static let doneKey = "expoImportDone"

    static func databaseURL() -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        for c in [docs.appendingPathComponent("SQLite/ndpass_v2.db"), lib.appendingPathComponent("LocalDatabase/ndpass_v2.db"), docs.appendingPathComponent("ndpass_v2.db")] where fm.fileExists(atPath: c.path) { return c }
        // Anywhere else in the container.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let walker = fm.enumerator(at: home, includingPropertiesForKeys: nil)
        while let u = walker?.nextObject() as? URL {
            if u.lastPathComponent == "ndpass_v2.db" { return u }
        }
        return nil
    }

    /// The Expo app stored absolute file:// paths, and the container path changes between
    /// installs, so photos are found again by file name.
    static func photo(for uri: String) -> Data? {
        guard !uri.isEmpty else { return nil }
        let name = (URL(string: uri)?.lastPathComponent ?? (uri as NSString).lastPathComponent)
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        for dir in [docs.appendingPathComponent("tickets"), docs, caches, caches.appendingPathComponent("ImagePicker")] {
            let u = dir.appendingPathComponent(name)
            if let d = try? Data(contentsOf: u) { return d }
        }
        if let u = URL(string: uri), u.isFileURL, let d = try? Data(contentsOf: u) { return d }
        return nil
    }

    @MainActor
    static func runIfNeeded(_ ctx: ModelContext) -> Int {
        guard !UserDefaults.standard.bool(forKey: doneKey), let url = databaseURL() else { return 0 }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else { return 0 }
        defer { sqlite3_close(db) }

        func rows(_ sql: String) -> [[String: String]] {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            var out: [[String: String]] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                var r: [String: String] = [:]
                for i in 0..<sqlite3_column_count(stmt) {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    if let c = sqlite3_column_text(stmt, i) { r[name] = String(cString: c) }
                }
                out.append(r)
            }
            return out
        }

        for s in rows("SELECT key, value FROM settings") {
            guard let k = s["key"], let v = s["value"], !v.isEmpty else { continue }
            if k == "anthropic_api_key", Keys.get(.anthropic) == nil { Keys.set(.anthropic, v) }
            if k == "tmdb_api_key", Keys.get(.tmdb) == nil { Keys.set(.tmdb, v) }
        }

        // The Expo app's own reminders are still queued; replace them rather than double up.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let existing = Set(((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).map(\.id))
        var groups: [String: UUID] = [:]
        var count = 0
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for r in rows("SELECT * FROM tickets") {
            let id = r["id"].flatMap(UUID.init(uuidString:)) ?? UUID()
            if existing.contains(id) { continue }
            let p = Pass(title: r["movieTitle"] ?? "Untitled")
            p.id = id
            p.venue = r["theater"] ?? ""
            p.date = r["date"] ?? ""
            p.time = PassTimes.normalizeTime(r["time"]) ?? (r["time"] ?? "")
            p.seat = r["seat"] ?? ""
            p.price = r["price"] ?? ""
            p.overview = r["overview"]
            p.posterPath = r["posterPath"]
            p.backdropPath = r["backdropPath"]
            p.tmdbID = r["tmdbId"].flatMap { Int($0) }
            if let c = r["createdAt"], let d = iso.date(from: c) ?? ISO8601DateFormatter().date(from: c) { p.createdAt = d }
            p.photo = photo(for: r["imageUri"] ?? "")
            let key = r["groupKey"] ?? "\(p.title)|\(p.venue)|\(p.date)|\(p.time)"
            if let g = groups[key] { p.group = g } else { groups[key] = p.group }
            ctx.insert(p)
            Reminders.schedule(p)
            count += 1
        }
        try? ctx.save()
        UserDefaults.standard.set(true, forKey: doneKey)
        return count
    }
}

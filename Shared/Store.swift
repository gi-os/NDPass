import Foundation
import SwiftData

/// The ticket database, settings and hand-off flags live in the App Group, so the share
/// sheet can read a ticket and file it without opening NDPass.
enum Store {
    static let group = "group.com.gios.ndpass"

    static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func container() -> ModelContainer {
        if let dir = folder {
            let url = dir.appendingPathComponent("NDPass.store")
            if let c = try? ModelContainer(for: Pass.self, configurations: ModelConfiguration(url: url)) { return c }
        }
        return try! ModelContainer(for: Pass.self)
    }

    /// Bumped by the share sheet after it saves; the app reloads when it sees a new value.
    private static let stampKey = "storeStamp"
    static var stamp: Double { defaults.double(forKey: stampKey) }
    static func touch() { defaults.set(Date().timeIntervalSince1970, forKey: stampKey) }

    /// First launch after the update: bring the old database (in the app's own container)
    /// and settings into the App Group. Runs before any container opens.
    static func migrate() {
        let d = defaults
        guard !d.bool(forKey: "migrated"), let dir = folder else { return }
        let fm = FileManager.default
        let target = dir.appendingPathComponent("NDPass.store")
        if let old = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store"),
           fm.fileExists(atPath: old.path), !fm.fileExists(atPath: target.path) {
            for suffix in ["", "-wal", "-shm"] {
                let src = URL(fileURLWithPath: old.path + suffix)
                guard fm.fileExists(atPath: src.path) else { continue }
                try? fm.copyItem(at: src, to: URL(fileURLWithPath: target.path + suffix))
            }
        }
        for k in ["reader", "aiConsent", "mapsApp"] {
            if let v = UserDefaults.standard.object(forKey: k), d.object(forKey: k) == nil { d.set(v, forKey: k) }
        }
        d.set(true, forKey: "migrated")
    }
}

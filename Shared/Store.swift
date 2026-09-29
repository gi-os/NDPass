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

    /// Every database NDPass has used: the app's own default store (before 2.4.0) and the
    /// App Group default SwiftData switched to on its own once the group was added (2.4.0).
    static var oldStores: [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        if let a = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first { urls.append(a.appendingPathComponent("default.store")) }
        if let g = folder { urls.append(g.appendingPathComponent("Library/Application Support/default.store")) }
        return urls.filter { fm.fileExists(atPath: $0.path) }
    }

    /// Bring every ticket from the old stores into this one, through SwiftData so photos
    /// (kept beside each store, not inside it) come too. Tickets already here keep their
    /// edits; only missing ones are added and missing photos filled in. Old files stay put.
    @MainActor
    static func mergeOld(into container: ModelContainer) -> Int {
        let d = defaults
        guard !d.bool(forKey: "mergedV2") else { return 0 }
        let ctx = container.mainContext
        var have: [UUID: Pass] = [:]
        for p in (try? ctx.fetch(FetchDescriptor<Pass>())) ?? [] { have[p.id] = p }
        var added = 0
        for url in oldStores {
            guard let old = try? ModelContainer(for: Pass.self, configurations: ModelConfiguration(url: url)) else { continue }
            let oc = ModelContext(old)
            for o in (try? oc.fetch(FetchDescriptor<Pass>())) ?? [] {
                if let p = have[o.id] {
                    if p.photo == nil { p.photo = o.photo }
                    if p.crop == nil { p.crop = o.crop }
                    if p.art == nil { p.art = o.art }
                    continue
                }
                let p = o.copy()
                ctx.insert(p); have[p.id] = p; added += 1
            }
        }
        try? ctx.save()
        d.set(true, forKey: "mergedV2")
        return added
    }

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

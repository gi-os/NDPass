import Foundation
import SwiftData

/// The ticket database, settings and hand-off flags live in the App Group, so the share
/// sheet can read a ticket and file it without opening NDPass.
enum Store {
    static let group = "group.com.gios.ndpass"

    static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static var storeURL: URL? { folder?.appendingPathComponent("NDPass.store") }

    /// The ticket database, or nil if it can't be opened (tried twice: the app and the share
    /// sheet may be opening it at the same moment). Never a different file instead: tickets
    /// saved into another store would be lost.
    static func openContainer() -> ModelContainer? {
        guard let url = storeURL else { return nil }
        for attempt in 0..<2 {
            if let c = try? ModelContainer(for: Pass.self, configurations: ModelConfiguration(url: url)) { return c }
            if attempt == 0 { Thread.sleep(forTimeInterval: 0.3) }
        }
        return nil
    }

    /// Set when the database couldn't be opened; the app says so instead of crashing.
    nonisolated(unsafe) static var openFailed = false

    /// For the app: the database, or an empty in-memory one (with `openFailed` set) so the
    /// app can still open and explain.
    static func container() -> ModelContainer {
        if let c = openContainer() { openFailed = false; return c }
        openFailed = true
        return try! ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
        guard !d.bool(forKey: "mergedV2"), !openFailed else { return 0 }
        // A fresh install has no old stores: nothing to do.
        guard !oldStores.isEmpty else { d.set(true, forKey: "mergedV2"); return 0 }
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
        do {
            try ctx.save()
            d.set(true, forKey: "mergedV2")   // only once it's really saved
        } catch {}
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
            // Photos bigger than ~100 KB live beside the store, in a folder named after it.
            let oldSupport = old.deletingLastPathComponent().appendingPathComponent(".default_SUPPORT")
            let newSupport = dir.appendingPathComponent(".NDPass_SUPPORT")
            if fm.fileExists(atPath: oldSupport.path), !fm.fileExists(atPath: newSupport.path) { try? fm.copyItem(at: oldSupport, to: newSupport) }
        }
        for k in ["reader", "aiConsent", "mapsApp"] {
            if let v = UserDefaults.standard.object(forKey: k), d.object(forKey: k) == nil { d.set(v, forKey: k) }
        }
        d.set(true, forKey: "migrated")
    }
}

import Foundation

/// Hand-off between the share extension and the app, through the App Group container:
/// `Inbox/<id>/item.json` plus an optional `image.jpg`. The extension writes; the app reads,
/// imports and deletes.
struct InboxItem: Codable {
    var id = UUID()
    var created = Date()
    var text: String?
    var url: String?
    var hasImage = false
}

enum Inbox {
    static let group = "group.com.gios.ndpass.shared"

    static var root: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("Inbox", isDirectory: true)
    }

    static func write(_ item: InboxItem, image: Data?) throws {
        guard let root else { throw CocoaError(.fileNoSuchFile) }
        let dir = root.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let image { try image.write(to: dir.appendingPathComponent("image.jpg")) }
        try JSONEncoder().encode(item).write(to: dir.appendingPathComponent("item.json"))
    }

    /// Everything waiting, oldest first.
    static func pending() -> [(InboxItem, Data?, URL)] {
        guard let root, let dirs = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return dirs.compactMap { dir -> (InboxItem, Data?, URL)? in
            guard let d = try? Data(contentsOf: dir.appendingPathComponent("item.json")),
                  let item = try? JSONDecoder().decode(InboxItem.self, from: d) else { return nil }
            let img = item.hasImage ? try? Data(contentsOf: dir.appendingPathComponent("image.jpg")) : nil
            return (item, img, dir)
        }
        .sorted { $0.0.created < $1.0.created }
    }

    static func remove(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }
}

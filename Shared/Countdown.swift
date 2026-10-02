import ActivityKit
import Foundation

/// The countdown to a showing: Lock Screen and Dynamic Island. Pictures (backdrop, logo, the
/// ticket's code) can't be fetched by the Live Activity itself, so the app saves them to the
/// App Group and the activity reads them from there.
struct CountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
    }
    var group: String          // Pass.group, for links back into the app
    var title: String
    var venue: String
    var time: String
    var seats: [String]
    var eyebrow: String        // "TONIGHT · METROGRAPH"
    var windowStart: Date      // when the progress bar starts filling
    var seller: String?        // "DICE" when only the seller's app can get you in
}

enum CountdownArt {
    static func folder(_ group: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass")?
            .appendingPathComponent("Countdown/\(group)", isDirectory: true)
    }
    static func backdrop(_ g: String) -> URL? { folder(g)?.appendingPathComponent("backdrop.jpg") }
    static func logo(_ g: String) -> URL? { folder(g)?.appendingPathComponent("logo.png") }
    static func code(_ g: String) -> URL? { folder(g)?.appendingPathComponent("code.png") }
    /// Backdrop and logo already put together, at the Dynamic Island's size.
    static func island(_ g: String) -> URL? { folder(g)?.appendingPathComponent("island.png") }
}

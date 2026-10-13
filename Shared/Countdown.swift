import ActivityKit
import AppIntents
import Foundation

/// The countdown to a showing (or a departure): Lock Screen and Dynamic Island. Pictures
/// (backdrop, logo, each ticket's code) can't be fetched by the Live Activity itself, so the
/// app saves them to the App Group and the activity reads them from there.
struct CountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        /// Which ticket's code is on the Lock Screen. Optional so activities started by an
        /// older build still decode.
        var index: Int?
    }
    var group: String          // Pass.group, for links back into the app
    var title: String
    var venue: String
    var time: String
    var seats: [String]        // one per ticket, in order; "" when a ticket has no seat
    var eyebrow: String        // "TONIGHT · METROGRAPH"
    var windowStart: Date      // when the progress bar starts filling
    var seller: String?        // "DICE" when only the seller's app can get you in
    // Added for trips; optional for the same reason as `index`.
    var kind: String?          // EventKind raw value
    var gate: String?          // "Track 9", "Gate B22"
    var destination: String?
    /// "METROGRAPH", "TRAIN · AMTRAK 2151". The day word in front of it is worked out when
    /// the activity is drawn, so a showing scheduled a day ahead doesn't say "TOMORROW" on
    /// the night. Nil for activities started by older builds (they use `eyebrow`).
    var place: String?
}

extension CountdownAttributes {
    /// "TONIGHT · METROGRAPH", from the start time as it is now.
    func eyebrow(start: Date, now: Date = Date()) -> String {
        guard let place else { return eyebrow }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: start)
        let day: String
        if cal.isDate(start, inSameDayAs: now) { day = hour >= 17 ? "TONIGHT" : "TODAY" }
        else if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(start, inSameDayAs: t) { day = "TOMORROW" }
        else { day = start.formatted(.dateTime.weekday(.abbreviated)).uppercased() }
        return place.isEmpty ? day : "\(day) · \(place)"
    }

    var isTransit: Bool { kind == "transit" }
    /// "Starts" / "Departs", "Doors open" / "Boarding".
    var verb: String { isTransit ? "Departs" : "Starts" }
    var doorWord: String { isTransit ? "BOARDING" : "DOORS OPEN" }
}

enum CountdownArt {
    static func folder(_ group: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass")?
            .appendingPathComponent("Countdown/\(group)", isDirectory: true)
    }
    static func backdrop(_ g: String) -> URL? { folder(g)?.appendingPathComponent("backdrop.jpg") }
    static func logo(_ g: String) -> URL? { folder(g)?.appendingPathComponent("logo.png") }
    /// The code for ticket `i` of the showing (ticket 0 keeps the old file name).
    static func code(_ g: String, _ i: Int = 0) -> URL? { folder(g)?.appendingPathComponent(i == 0 ? "code.png" : "code-\(i).png") }
    /// Backdrop and logo already put together, at the Dynamic Island's size.
    static func island(_ g: String) -> URL? { folder(g)?.appendingPathComponent("island.png") }
}

/// Tapping a seat on the Lock Screen swaps in that ticket's code, without opening NDPass.
struct ShowTicketCode: LiveActivityIntent {
    static var title: LocalizedStringResource = "Show ticket code"
    static var isDiscoverable = false

    @Parameter(title: "Showing") var group: String
    @Parameter(title: "Ticket") var index: Int

    init() {}
    init(group: String, index: Int) { self.group = group; self.index = index }

    func perform() async throws -> some IntentResult {
        for a in Activity<CountdownAttributes>.activities where a.attributes.group == group {
            var s = a.content.state
            s.index = index
            await a.update(ActivityContent(state: s, staleDate: a.content.staleDate, relevanceScore: 100))
        }
        return .result()
    }
}

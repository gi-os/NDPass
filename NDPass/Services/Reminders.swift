import UserNotifications

/// Two reminders per showing: three hours before and thirty minutes before (an hour before a
/// flight). Rebuilt from the tickets every time they change, so edits, merges and deletes are
/// always reflected, and only the soonest showings are queued: iOS keeps at most 64.
enum Reminders {
    static let maxShowings = 30

    struct Item {
        let id: String, title: String, body: String, when: Date
    }

    /// The reminders the tickets call for, soonest first.
    static func plan(_ passes: [Pass], now: Date = Date()) -> [Item] {
        let groups = Showings.groups(passes, archived: false).filter { ($0.first?.start).map { $0 > now } ?? false }
        var items: [Item] = []
        for g in groups.prefix(maxShowings) {
            guard let p = g.first, let start = p.start else { continue }
            let transit = p.kind == .transit
            let place = p.venue.isEmpty ? (transit ? "your station" : "the venue") : p.venue
            let seats = g.map(\.seat).filter { !$0.isEmpty }
            let seatText: String? = seats.isEmpty ? nil
                : seats.allSatisfy({ $0.contains(where: \.isNumber) }) ? (seats.count > 1 ? "Seats " : "Seat ") + seats.joined(separator: ", ")
                : seats.joined(separator: ", ")
            let gate = p.gate.isEmpty ? nil : "\(p.transitMode.gateLabel) \(p.gate)"
            let detail = [gate, seatText].compactMap { $0 }.joined(separator: " · ")
            let flight = transit && p.transitMode == .flight
            let second: (String, TimeInterval) = flight ? ("1h", 3600) : ("30m", 1800)
            let firstBody = transit ? "Departs in three hours from \(place)" : "In three hours at \(place)"
            let soonWords = flight ? "Departs in an hour." : transit ? "Departs in 30 minutes." : "In 30 minutes."
            let key = p.group.uuidString
            for (tag, lead, body) in [("3h", 3 * 3600.0, firstBody), (second.0, second.1, soonWords + (detail.isEmpty ? "" : " " + detail))] {
                let when = start.addingTimeInterval(-lead)
                guard when > now else { continue }
                items.append(Item(id: "ndp.\(key).\(tag)", title: p.title, body: body, when: when))
            }
        }
        return items.sorted { $0.when < $1.when }
    }

    /// Replace every queued reminder with the ones the tickets call for now. Asks for
    /// permission the first time there's something to remind about.
    static func sync(_ passes: [Pass]) {
        let items = plan(passes)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                #if NDPASS_EXTENSION
                return   // the app asks, not the share sheet
                #else
                guard !items.isEmpty else { return }
                center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in if ok { replace(items) } }
                return
                #endif
            }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            replace(items)
        }
    }

    private static func replace(_ items: [Item]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        for item in items.prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.when)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}

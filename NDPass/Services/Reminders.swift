import UserNotifications

/// Three hours before and thirty minutes before.
enum Reminders {
    static func requestAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(_ p: Pass) {
        cancel(p.id)
        guard let start = p.start, start > Date() else { return }
        let times: [(String, Date, String)] = [
            ("3h", start.addingTimeInterval(-3 * 3600), "In three hours at \(p.venue.isEmpty ? "the venue" : p.venue)"),
            ("30m", start.addingTimeInterval(-1800), "In 30 minutes. Seat \(p.seat.isEmpty ? "on the ticket" : p.seat)")
        ]
        var cal = Calendar.current; cal.timeZone = .current
        for (tag, when, body) in times {
            guard when > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = p.title
            content.body = body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let req = UNNotificationRequest(identifier: "\(p.id.uuidString)-\(tag)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            UNUserNotificationCenter.current().add(req)
        }
    }

    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["9am", "2h", "3h", "30m"].map { "\(id.uuidString)-\($0)" })
    }
}

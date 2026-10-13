import EventKit
import Foundation

/// Upcoming tickets as calendar events, automatically, once it's turned on in Settings.
///
/// - A showing gets an event unless your calendar already has one for it (same name or
///   venue, around the same time), say from the seller's email.
/// - NDPass keeps the events it made in step with the ticket (time, title, venue, seats) and
///   moves them if you pick another calendar.
/// - Delete a ticket and its upcoming event goes too. Delete the event yourself and NDPass
///   doesn't add it back.
/// - A date with no time yet (TBD) is an all-day event; no date yet, no event.
/// EventKit work happens on its own queue, one sync at a time.
enum CalendarSync {
    private static let enabledKey = "calendarOn"
    private static let calendarKey = "calendarID"
    private static let mapKey = "calendarEvents"      // showing → event NDPass made
    private static let skipKey = "calendarSkip"       // showings that already had one, or whose event you deleted

    static var enabled: Bool {
        get { Store.defaults.bool(forKey: enabledKey) }
        set { Store.defaults.set(newValue, forKey: enabledKey) }
    }
    /// The calendar new events go in; nil for the phone's default.
    static var calendarID: String? {
        get { Store.defaults.string(forKey: calendarKey) }
        set { Store.defaults.set(newValue, forKey: calendarKey) }
    }
    static var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var denied: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .denied || s == .restricted || s == .writeOnly
    }
    static var madeAny: Bool { !(Store.defaults.dictionary(forKey: mapKey) ?? [:]).isEmpty }

    /// Full access, so NDPass can see whether an event is already there before adding one.
    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    /// The calendars events can go in, for Settings.
    static func writableCalendars() -> [EKCalendar] {
        guard authorized else { return [] }
        return EKEventStore().calendars(for: .event).filter(\.allowsContentModifications)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func defaultCalendarName() -> String? {
        guard authorized else { return nil }
        return EKEventStore().defaultCalendarForNewEvents?.title
    }

    // MARK: plan

    struct Plan: Equatable {
        let key: String
        let title: String
        let location: String
        let start: Date
        let end: Date
        let allDay: Bool
        let notes: String
        let url: URL?
        /// Words for spotting an event that's already there.
        let titleWords: Set<String>
        let venueWords: Set<String>
    }

    static func words(_ s: String) -> Set<String> {
        let skip: Set<String> = ["the", "and", "vs", "at", "for", "with", "from", "tickets", "ticket", "your", "theatre", "theater", "cinema", "cinemas", "stadium", "arena", "center", "centre"]
        return Set(s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 && !skip.contains($0) })
    }

    /// The events the tickets call for, from the next 120 days of dated showings.
    static func plan(_ passes: [Pass], now: Date = Date()) -> [Plan] {
        let horizon = now.addingTimeInterval(120 * 86400)
        var out: [Plan] = []
        for g in Showings.groups(passes, archived: false) {
            guard let p = g.first, !p.isDeleted, let day = PassTimes.day(p.date), day < horizon else { continue }
            let transit = p.kind == .transit
            let start: Date, end: Date, allDay: Bool
            if let s = p.start {
                start = s
                if transit, let a = p.arrivalDate { end = a }
                else if let r = p.runtime, p.kind == .movie { end = s.addingTimeInterval(Double(r + 15) * 60) }
                else { end = s.addingTimeInterval(Double(defaultMinutes(p)) * 60) }
                allDay = false
            } else {
                start = day; end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400); allDay = true
            }
            guard end > now else { continue }
            let title: String
            if transit {
                let num = [p.carrier, p.trip].filter { !$0.isEmpty }.joined(separator: " ")
                title = num.isEmpty ? p.title : "\(num) · \(p.title)"
            } else { title = p.title }
            let seats = g.map(\.seat).filter { !$0.isEmpty }
            var notes: [String] = []
            if !seats.isEmpty { notes.append((seats.count > 1 ? "Seats: " : "Seat: ") + seats.joined(separator: ", ")) }
            if transit, !p.gate.isEmpty { notes.append("\(p.transitMode.gateLabel): \(p.gate)") }
            if let code = g.first(where: { !$0.bookingCode.isEmpty })?.bookingCode { notes.append("Booking: \(code)") }
            notes.append("Added by NDPass")
            out.append(Plan(key: p.group.uuidString, title: title, location: p.venue, start: start, end: end, allDay: allDay,
                            notes: notes.joined(separator: "\n"), url: URL(string: "ndpass://ticket?group=\(p.group.uuidString)"),
                            titleWords: words(p.title), venueWords: words(p.venue)))
        }
        return out
    }

    private static func defaultMinutes(_ p: Pass) -> Int {
        switch p.kind {
        case .movie: return 150
        case .sports, .concert: return 180
        case .theater: return 150
        case .event: return 120
        case .transit: return 60
        }
    }

    // MARK: sync

    private static let queue = DispatchQueue(label: "ndpass.calendar")

    /// Bring the calendar in line with the tickets. Quietly does nothing until it's turned on
    /// and allowed.
    static func sync(_ passes: [Pass]) {
        guard enabled, authorized else { return }
        let plans = plan(passes)
        let target = calendarID
        queue.async { apply(plans, calendarID: target) }
    }

    /// Remove the upcoming events NDPass added (Settings).
    static func removeAll(completion: @escaping () -> Void = {}) {
        queue.async {
            let store = EKEventStore()
            let map = Store.defaults.dictionary(forKey: mapKey) as? [String: String] ?? [:]
            for (_, id) in map {
                if let e = store.event(withIdentifier: id), e.endDate > Date() { try? store.remove(e, span: .thisEvent, commit: false) }
            }
            try? store.commit()
            Store.defaults.removeObject(forKey: mapKey)
            Store.defaults.removeObject(forKey: skipKey)
            DispatchQueue.main.async(execute: completion)
        }
    }

    private static func apply(_ plans: [Plan], calendarID: String?) {
        guard authorized else { return }
        let store = EKEventStore()
        let d = Store.defaults
        var map = d.dictionary(forKey: mapKey) as? [String: String] ?? [:]
        var skip = Set(d.stringArray(forKey: skipKey) ?? [])
        let keys = Set(plans.map(\.key))
        let now = Date()

        // Tickets that are gone: their upcoming events go too; past ones are just forgotten.
        for (k, id) in map where !keys.contains(k) {
            if let e = store.event(withIdentifier: id), e.startDate > now, e.notes?.contains("Added by NDPass") == true {
                try? store.remove(e, span: .thisEvent, commit: false)
            }
            map[k] = nil
        }

        let calendar = calendarID.flatMap { store.calendar(withIdentifier: $0) } ?? store.defaultCalendarForNewEvents
        for plan in plans {
            if let id = map[plan.key] {
                guard let e = store.event(withIdentifier: id) else {
                    // You deleted it from your calendar: leave it deleted.
                    map[plan.key] = nil; skip.insert(plan.key); continue
                }
                if fill(e, plan) || (calendar != nil && e.calendar?.calendarIdentifier != calendar?.calendarIdentifier) {
                    if let calendar { e.calendar = calendar }
                    try? store.save(e, span: .thisEvent, commit: false)
                }
                continue
            }
            if skip.contains(plan.key) { continue }
            if alreadyThere(plan, store: store) { skip.insert(plan.key); continue }
            guard let calendar else { continue }
            let e = EKEvent(eventStore: store)
            e.calendar = calendar
            _ = fill(e, plan)
            e.availability = .busy
            do {
                try store.save(e, span: .thisEvent, commit: false)
                if let id = e.eventIdentifier { map[plan.key] = id }
            } catch {}
        }
        try? store.commit()
        // Identifiers are final once committed.
        d.set(map, forKey: mapKey)
        d.set(Array(skip.intersection(keys)), forKey: skipKey)
    }

    /// Copy the plan onto the event; true if anything changed.
    @discardableResult
    private static func fill(_ e: EKEvent, _ p: Plan) -> Bool {
        var changed = false
        if e.title != p.title { e.title = p.title; changed = true }
        if (e.location ?? "") != p.location { e.location = p.location.isEmpty ? nil : p.location; changed = true }
        if e.isAllDay != p.allDay { e.isAllDay = p.allDay; changed = true }
        if e.startDate != p.start { e.startDate = p.start; changed = true }
        if e.endDate != p.end { e.endDate = p.end; changed = true }
        if (e.notes ?? "") != p.notes { e.notes = p.notes; changed = true }
        if e.url != p.url { e.url = p.url; changed = true }
        return changed
    }

    /// An event you already have for this showing: around the same time, with the show's name
    /// or the venue in it.
    private static func alreadyThere(_ p: Plan, store: EKEventStore) -> Bool {
        let from = p.start.addingTimeInterval(-3 * 3600), to = p.end.addingTimeInterval(3 * 3600)
        let events = store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: nil))
        return events.contains { e in
            let near = p.allDay || e.isAllDay ? Calendar.current.isDate(e.startDate, inSameDayAs: p.start) : abs(e.startDate.timeIntervalSince(p.start)) <= 2 * 3600
            guard near else { return false }
            let t = words((e.title ?? "") + " " + (e.notes ?? ""))
            let loc = words(e.location ?? "")
            return !p.titleWords.isDisjoint(with: t) || (!p.venueWords.isEmpty && !p.venueWords.isDisjoint(with: loc.union(t)))
        }
    }
}

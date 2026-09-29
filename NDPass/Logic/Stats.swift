import Foundation

/// Everything the Stats page shows, worked out once from the tickets. A showing (a group of
/// tickets for the same event) counts as one visit; money counts every ticket.
struct Stats {
    struct KindLine: Identifiable { let kind: EventKind; let visits: Int; let spent: Double; var id: String { kind.rawValue } }
    struct MonthCount: Identifiable { let month: Int; let count: Int; var id: Int { month } }

    let tickets: Int
    let visits: Int
    let spent: Double
    let averagePrice: Double?
    let first: Date?

    let longestStreak: Int          // weeks in a row with a showing
    let currentStreak: Int
    let busiestMonth: (label: String, count: Int)?
    let busiestWeek: Int

    let kinds: [KindLine]
    let topTeam: (String, Int)?
    let topArtist: (String, Int)?
    let mostSeen: (String, Int)?

    let favoriteDay: String?
    let usualTime: String?
    let hoursWatched: Int
    let favoriteRow: (String, Int)?

    let venues: Int
    let newVenuesThisYear: Int
    let favoriteVenue: (String, Int)?
    let venueNames: [String]

    let year: Int
    let byMonth: [MonthCount]

    static func price(_ s: String) -> Double { Double(s.filter { "0123456789.".contains($0) }) ?? 0 }

    init(_ passes: [Pass], now: Date = Date(), calendar: Calendar = .current) {
        let cal = calendar
        let groups = Dictionary(grouping: passes, by: \.group).values.map { $0 }
        let shows = groups.compactMap { g -> (Pass, Date)? in
            guard let p = g.first, let d = p.start ?? PassTimes.day(p.date) else { return nil }
            return (p, d)
        }.sorted { $0.1 < $1.1 }
        let past = shows.filter { $0.1 <= now }

        tickets = passes.count
        visits = groups.count
        let prices = passes.map { Self.price($0.price) }.filter { $0 > 0 }
        spent = prices.reduce(0, +)
        averagePrice = prices.isEmpty ? nil : spent / Double(prices.count)
        first = shows.first?.1

        // Weeks in a row: count distinct (yearForWeekOfYear, weekOfYear), walk them in order.
        let weekKeys = Set(past.map { cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.1) }
            .compactMap { c -> Date? in cal.date(from: c) })
        let weeks = weekKeys.sorted()
        var best = 0, run = 0
        var prev: Date?
        for w in weeks {
            if let p = prev, let next = cal.date(byAdding: .weekOfYear, value: 1, to: p), cal.isDate(next, inSameDayAs: w) { run += 1 } else { run = 1 }
            best = max(best, run); prev = w
        }
        longestStreak = best
        var cur = 0
        if let thisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
            var w = weekKeys.contains(thisWeek) ? thisWeek : cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
            while weekKeys.contains(w) { cur += 1; w = cal.date(byAdding: .weekOfYear, value: -1, to: w)! }
        }
        currentStreak = cur

        let byMonthAll = Dictionary(grouping: past, by: { cal.dateComponents([.year, .month], from: $0.1) }).mapValues(\.count)
        if let top = byMonthAll.max(by: { $0.value < $1.value }), let d = cal.date(from: top.key) {
            busiestMonth = (d.formatted(.dateTime.month(.wide).year()), top.value)
        } else { busiestMonth = nil }
        busiestWeek = Dictionary(grouping: past, by: { cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.1) }).values.map(\.count).max() ?? 0

        kinds = EventKind.allCases.map { k in
            KindLine(kind: k, visits: groups.filter { $0.first?.kind == k }.count,
                     spent: passes.filter { $0.kind == k }.map { Self.price($0.price) }.reduce(0, +))
        }.filter { $0.visits > 0 }
        func top(_ names: [String]) -> (String, Int)? {
            let c = Dictionary(grouping: names.filter { !$0.isEmpty }, by: { $0 }).mapValues(\.count)
            return c.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }.map { ($0.key, $0.value) }
        }
        let firsts = groups.compactMap(\.first)
        topTeam = top(firsts.filter { $0.kind == .sports }.flatMap { p -> [String] in
            guard let (a, b) = Matchup.split(p.title) else { return [] }; return [a, b] })
        topArtist = top(firsts.filter { $0.kind == .concert }.map(\.title))
        let seen = top(firsts.filter { $0.kind == .movie }.map(\.title))
        mostSeen = (seen?.1 ?? 0) > 1 ? seen : nil

        let days = past.map { cal.component(.weekday, from: $0.1) }
        favoriteDay = top(days.map { cal.weekdaySymbols[$0 - 1] })?.0
        let hours = past.compactMap { $0.0.start.map { cal.component(.hour, from: $0) } }.sorted()
        if !hours.isEmpty {
            let h = hours[hours.count / 2]
            usualTime = h < 12 ? "Mornings" : h < 17 ? "Afternoons" : h < 21 ? "Evenings" : "Late nights"
        } else { usualTime = nil }
        hoursWatched = past.filter { $0.0.kind == .movie }.map { $0.0.runtime ?? 0 }.reduce(0, +) / 60
        let rows = passes.compactMap { p -> String? in
            // "F12", "Row F Seat 12", "F-12" → F
            let s = p.seat.uppercased()
            if let m = s.firstMatch(of: #/ROW\s*([A-Z]{1,2})/#) { return String(m.1) }
            if let m = s.firstMatch(of: #/^([A-Z]{1,2})\s*-?\s*\d/#) { return String(m.1) }
            return nil
        }
        favoriteRow = top(rows)

        let year = cal.component(.year, from: now)
        self.year = year
        let venueFirst = Dictionary(grouping: shows.filter { !$0.0.venue.isEmpty }, by: { $0.0.venue }).mapValues { $0.map(\.1).min()! }
        venues = venueFirst.count
        newVenuesThisYear = venueFirst.values.filter { cal.component(.year, from: $0) == year }.count
        favoriteVenue = top(firsts.map(\.venue))
        venueNames = venueFirst.keys.sorted()
        byMonth = (1...12).map { m in MonthCount(month: m, count: shows.filter { cal.component(.year, from: $0.1) == year && cal.component(.month, from: $0.1) == m }.count) }
    }
}

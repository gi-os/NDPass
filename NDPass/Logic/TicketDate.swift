import Foundation

/// Which year a ticket belongs to when the paper doesn't say. Ported rule for rule from
/// BrightPasses' TicketDate.kt.
///
/// Stubs print "DEC 18" and leave the year off. The model is told to omit the year whenever
/// the paper omits it, and the year is decided here: a date with no year means its next
/// occurrence, with a two-day grace window so a late showing photographed after midnight
/// doesn't jump eleven months forward. A year the model reports far from today is treated as
/// invented; a year a person types is kept.
enum TicketDate {
    static let graceDays = 2
    static let yearSlack = 1
    static let maxYearsAhead = 8

    static func resolveFromModel(_ raw: String?, today: Date = Date(), calendar: Calendar = .current) -> String? {
        resolve(raw, today: today, trustWrittenYear: false, cal: calendar)
    }

    static func resolveTyped(_ raw: String?, today: Date = Date(), calendar: Calendar = .current) -> String? {
        resolve(raw, today: today, trustWrittenYear: true, cal: calendar)
    }

    private struct YMD: Comparable {
        let y: Int, m: Int, d: Int
        var iso: String { String(format: "%04d-%02d-%02d", y, m, d) }
        static func < (a: YMD, b: YMD) -> Bool { (a.y, a.m, a.d) < (b.y, b.m, b.d) }
    }

    private static func valid(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) -> YMD? {
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        guard let date = cal.date(from: c) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        guard back.year == y, back.month == m, back.day == d else { return nil }
        return YMD(y: y, m: m, d: d)
    }

    private static func ymd(_ date: Date, _ cal: Calendar) -> YMD {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return YMD(y: c.year ?? 2000, m: c.month ?? 1, d: c.day ?? 1)
    }

    private static func resolve(_ raw: String?, today: Date, trustWrittenYear: Bool, cal: Calendar) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let now = ymd(today, cal)

        if let m = text.wholeMatch(of: #/(\d{4})-(\d{1,2})-(\d{1,2})/#) {
            let y = Int(m.1)!, mo = Int(m.2)!, d = Int(m.3)!
            if let written = valid(y, mo, d, cal), trustWrittenYear || abs(y - now.y) <= yearSlack { return written.iso }
            return next(mo, d, today, cal)?.iso ?? text
        }
        if let m = text.wholeMatch(of: #/-{0,2}(\d{1,2})-(\d{1,2})/#) {
            return next(Int(m.1)!, Int(m.2)!, today, cal)?.iso ?? text
        }
        // Anything else stays as it came, where it can be seen and corrected.
        return text
    }

    private static func next(_ m: Int, _ d: Int, _ today: Date, _ cal: Calendar) -> YMD? {
        guard let early = cal.date(byAdding: .day, value: -graceDays, to: today) else { return nil }
        let earliest = ymd(early, cal)
        let year = ymd(today, cal).y
        for y in year...(year + maxYearsAhead) {
            guard let c = valid(y, m, d, cal) else { continue }
            if !(c < earliest) { return c }
        }
        return nil
    }
}

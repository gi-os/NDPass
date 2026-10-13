import Foundation

/// Which year a ticket belongs to when the paper doesn't say. Ported from BrightPasses'
/// TicketDate.kt, with one change: a printed year is kept, so old stubs keep their own year.
///
/// Stubs print "DEC 18" and leave the year off. The readers are told to omit the year
/// whenever the paper omits it, and the year is decided here: a date with no year means its
/// next occurrence, with a two-day grace window so a late showing photographed after midnight
/// doesn't jump eleven months forward. A year the reader reports is kept when it's in the
/// past or next year; when the ticket's own text is known (the on-device reader) the year
/// must appear in it, or it's treated as made up. Dates are always Gregorian, whatever
/// calendar the phone uses.
enum TicketDate {
    static let graceDays = 2
    static let maxYearsAhead = 8
    static let earliestYear = 1950

    static var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c
    }

    /// `evidence`: the text read off the ticket, when there is one. A year that isn't in it
    /// was invented by the model.
    static func resolveFromModel(_ raw: String?, evidence: String? = nil, today: Date = Date(), calendar: Calendar = gregorian) -> String? {
        resolve(raw, today: today, trust: .model(evidence), cal: calendar)
    }

    static func resolveTyped(_ raw: String?, today: Date = Date(), calendar: Calendar = gregorian) -> String? {
        resolve(raw, today: today, trust: .typed, cal: calendar)
    }

    private enum Trust { case typed, model(String?) }

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

    private static func resolve(_ raw: String?, today: Date, trust: Trust, cal: Calendar) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let now = ymd(today, cal)

        if let m = text.wholeMatch(of: #/([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})/#), let y = Int(m.1), let mo = Int(m.2), let d = Int(m.3) {
            let keep: Bool
            switch trust {
            case .typed: keep = true
            case .model(let evidence):
                let plausible = y >= earliestYear && y <= now.y + 1
                let printed = evidence.map { $0.contains(String(m.1)) || $0.contains("/" + String(m.1).suffix(2)) } ?? true
                keep = plausible && printed
            }
            if keep, let written = valid(y, mo, d, cal) { return written.iso }
            return next(mo, d, today, cal)?.iso ?? text
        }
        if let m = text.wholeMatch(of: #/-{0,2}([0-9]{1,2})-([0-9]{1,2})/#), let mo = Int(m.1), let d = Int(m.2) {
            return next(mo, d, today, cal)?.iso ?? text
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

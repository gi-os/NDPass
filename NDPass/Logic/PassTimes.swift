import Foundation

/// Times and dates as a ticket shows them. From PassTimes.kt and ShowTime.
enum PassTimes {
    static let defaultRuntimeMinutes = 180

    private static func fmt(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = f; return d
    }

    /// "1:30 AM" on a movie ticket is a misread "1:30 PM": nothing starts 1-6 AM.
    static func normalizeTime(_ time: String?) -> String? {
        guard let t = time?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return time }
        guard let m = t.wholeMatch(of: #/(?i)(\d{1,2}):(\d{2})\s*([ap])\.?m\.?/#) else { return time }
        let hour = Int(m.1) ?? 0
        var mer = m.3.uppercased()
        if mer == "A" && (1...6).contains(hour) { mer = "P" }
        return "\(hour == 0 ? 12 : hour):\(m.2) \(mer)M"
    }

    static func start(date: String?, time: String?, tz: TimeZone = .current) -> Date? {
        guard let date, let time, !date.isEmpty, !time.isEmpty else { return nil }
        let t = time.trimmingCharacters(in: .whitespaces).uppercased()
        for f in ["yyyy-MM-dd h:mm a", "yyyy-MM-dd hh:mm a", "yyyy-MM-dd H:mm"] {
            let df = fmt(f); df.timeZone = tz
            if let d = df.date(from: "\(date) \(t)") { return d }
        }
        return nil
    }

    static func day(_ date: String?, tz: TimeZone = .current) -> Date? {
        guard let date else { return nil }
        let df = fmt("yyyy-MM-dd"); df.timeZone = tz
        return df.date(from: date)
    }

    static func end(date: String?, time: String?, runtime: Int?) -> Date? {
        start(date: date, time: time)?.addingTimeInterval(Double(runtime ?? defaultRuntimeMinutes) * 60)
    }

    static func isArchived(date: String?, time: String?, runtime: Int?, now: Date = Date()) -> Bool {
        if let e = end(date: date, time: time, runtime: runtime) { return now > e }
        if let d = day(date) { return now > d.addingTimeInterval(36 * 3600) }
        return false
    }

    /// "2026-08-06" -> "August 6th"
    static func humanDate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let df = fmt("yyyy-MM-dd")
        guard let d = df.date(from: iso) else { return iso }
        let day = Calendar(identifier: .gregorian).component(.day, from: d)
        let suffix: String
        if (11...13).contains(day) { suffix = "th" }
        else { switch day % 10 { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" } }
        return "\(fmt("MMMM").string(from: d)) \(day)\(suffix)"
    }

    /// "Regal Union Square" rather than "REGAL UNION SQUARE".
    static func titleCase(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return s }
        let small: Set<String> = ["of", "the", "at", "and", "in", "on", "a"]
        let words = s.lowercased().split(separator: " ").enumerated().map { i, w -> String in
            let w = String(w)
            if i > 0 && small.contains(w) { return w }
            if ["amc", "imax", "nyc", "usa", "bam", "ifc", "nba", "nfl", "mlb", "nhl"].contains(w) { return w.uppercased() }
            return w.prefix(1).uppercased() + w.dropFirst()
        }
        return words.joined(separator: " ")
    }
}

/// "Knicks vs Celtics" → ("Knicks", "Celtics"). The separator must be a whole word.
enum Matchup {
    static func split(_ title: String?) -> (String, String)? {
        guard let t = title?.trimmingCharacters(in: .whitespaces),
              let r = t.firstMatch(of: #/(?i)\s+(?:vs\.?|v\.?|at|@)\s+/#) else { return nil }
        let a = String(t[..<r.range.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: " :-–—"))
        let b = String(t[r.range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty, !b.isEmpty else { return nil }
        return (a, b)
    }
}

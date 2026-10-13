import Foundation

/// Times and dates as a ticket shows them. From PassTimes.kt and ShowTime.
enum PassTimes {
    static let defaultRuntimeMinutes = 180

    /// Formatters are slow to make and these run for every ticket on every redraw, so each
    /// format/time zone pair is made once. (DateFormatter is thread-safe for these uses.)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: DateFormatter] = [:]
    private static func fmt(_ f: String, _ tz: TimeZone = .current) -> DateFormatter {
        let key = f + "|" + tz.identifier
        lock.lock(); defer { lock.unlock() }
        if let d = cache[key] { return d }
        let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.calendar = Calendar(identifier: .gregorian)
        d.timeZone = tz; d.dateFormat = f
        cache[key] = d
        return d
    }

    /// "1:30 AM" on a movie ticket is a misread "1:30 PM": nothing starts 1-6 AM.
    /// `literal` (trains, flights, and times picked by hand) trusts the time as given.
    static func normalizeTime(_ time: String?, literal: Bool = false) -> String? {
        guard let t = time?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return time }
        // 24-hour ("19:30", "19h30", "1930") → "7:30 PM". Always shown with AM/PM.
        if let m = t.wholeMatch(of: #/([0-9]{1,2})\s*[:h.]?\s*([0-9]{2})/#), let h = Int(m.1), let mm = Int(m.2), h < 24, mm < 60 {
            let hour = h % 12 == 0 ? 12 : h % 12
            var mer = h >= 12 ? "PM" : "AM"
            // Without AM/PM a single-digit hour on a ticket is evening ("7:30"); 10 and 11
            // stay morning (matinees). A leading zero ("09:00") is a real 24-hour morning time.
            let zeroPadded = m.1.count == 2 && m.1.hasPrefix("0")
            if !literal && !zeroPadded && mer == "AM" && (1...9).contains(h) { mer = "PM" }
            return String(format: "%d:%02d %@", hour, mm, mer)
        }
        // "7:30 PM", "7:30pm", "7 PM", "7pm"
        guard let m = t.wholeMatch(of: #/(?i)([0-9]{1,2})(?::([0-9]{2}))?\s*([ap])\.?\s*m\.?/#), let hour = Int(m.1), (0...12).contains(hour) else { return time }
        let minutes = m.2.map(String.init) ?? "00"
        var mer = m.3.uppercased()
        if !literal && mer == "A" && (1...6).contains(hour) { mer = "P" }
        return "\(hour == 0 ? 12 : hour):\(minutes) \(mer)M"
    }

    static func start(date: String?, time: String?, tz: TimeZone = .current) -> Date? {
        guard let date, let time, !date.isEmpty, !time.isEmpty else { return nil }
        let t = time.trimmingCharacters(in: .whitespaces).uppercased()
        for f in ["yyyy-MM-dd h:mm a", "yyyy-MM-dd hh:mm a", "yyyy-MM-dd H:mm"] {
            if let d = fmt(f, tz).date(from: "\(date) \(t)") { return d }
        }
        return nil
    }

    static func day(_ date: String?, tz: TimeZone = .current) -> Date? {
        guard let date, date.count == 10 else { return nil }
        return fmt("yyyy-MM-dd", tz).date(from: date)
    }

    /// "7:30 PM" for a date, whatever the phone's 12/24-hour setting (the app shows AM/PM).
    static func clock(_ d: Date) -> String { fmt("h:mm a").string(from: d) }

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
        guard let d = fmt("yyyy-MM-dd").date(from: iso) else { return iso }
        let day = Calendar(identifier: .gregorian).component(.day, from: d)
        let suffix: String
        if (11...13).contains(day) { suffix = "th" }
        else { switch day % 10 { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" } }
        return "\(fmt("MMMM").string(from: d)) \(day)\(suffix)"
    }

    /// "Regal Union Square" rather than "REGAL UNION SQUARE".
    /// "TBD", "TBA", "To be announced", "TBC": no date or time yet.
    static func tbd(_ s: String?) -> Bool {
        guard let t = s?.trimmingCharacters(in: .whitespaces).lowercased(), !t.isEmpty else { return false }
        return ["tbd", "tba", "tbc", "to be determined", "to be announced", "to be confirmed"].contains { t.contains($0) }
    }

    /// Title Case for text read in all capitals or all lowercase; mixed case is left as
    /// printed (it's usually deliberate: "iPhone", "McCarren", "The xx").
    static func display(_ s: String) -> String {
        let letters = s.filter(\.isLetter)
        guard !letters.isEmpty, letters == letters.uppercased() || letters == letters.lowercased() else { return s }
        return titleCase(s, keepCaps: letters == letters.uppercased()) ?? s
    }

    /// Short words that are words, not acronyms, when a ticket prints them in capitals.
    private static let shortWords: Set<String> = [
        "a", "an", "the", "and", "or", "of", "at", "in", "on", "to", "by", "for", "vs", "v", "my", "me",
        "we", "you", "new", "big", "red", "sea", "sky", "sun", "art", "man", "war", "day", "one", "two", "all", "her",
        "his", "our", "out", "up", "it", "is", "be", "no", "yes", "top", "old", "bar", "inn", "hub", "bad", "mad",
        "hot", "cat", "dog", "boy", "kid", "guy", "end", "way", "lot", "fun", "pop", "jam", "hip", "hop", "lab", "box",
        "pit", "row", "act", "eve", "fox", "ice", "key", "law", "map", "net", "oak", "pie", "rex", "sin", "tea", "toy",
        "zoo", "air", "age", "san", "los", "las", "del", "dos", "von", "van", "bay", "st", "mt", "ft", "dr", "jr",
        "sr", "mr", "ms", "now", "who", "how", "why", "yet", "off", "its", "can", "not", "see", "run", "cup", "ten",
        "six", "go", "do", "so", "he", "she", "him", "us", "if", "as", "am", "pm", "east", "west", "le", "la",
        "el", "de", "da", "di", "du"
    ]
    /// Always capitals.
    private static let acronyms: Set<String> = ["amc", "imax", "nyc", "usa", "bam", "ifc", "nba", "nfl", "mlb", "nhl", "wnba",
                                                "nwsl", "mls", "pwhl", "ncaa", "ufc", "wwe", "tcl", "bfi", "moma", "lacma", "ii", "iii", "iv"]

    /// `keepCaps`: the text was all capitals, so short acronyms ("TD Garden", "AC/DC", "RRR",
    /// "M3GAN", "AT&T") stay that way.
    static func titleCase(_ s: String?, keepCaps: Bool = false) -> String? {
        guard let s, !s.isEmpty else { return s }
        let small: Set<String> = ["of", "the", "at", "and", "in", "on", "a", "vs", "vs.", "v", "for", "to", "by", "an", "or"]
        func word(_ raw: String, first: Bool) -> String {
            let w = raw.lowercased()
            if !first && small.contains(w) { return w }
            if acronyms.contains(w) { return w.uppercased() }
            let bare = w.filter(\.isLetter)
            if keepCaps {
                // Digits or symbols inside a word mark a name as printed: M3GAN, AC/DC, AT&T, U2.
                if raw.contains(where: { $0.isNumber }) && raw.contains(where: \.isLetter) || raw.contains("/") || raw.contains("&") { return raw }
                if (2...3).contains(bare.count) && !shortWords.contains(bare) { return raw }
            }
            // T-Mobile, Jean-Luc
            if w.contains("-") { return w.split(separator: "-", omittingEmptySubsequences: false).map { cap(String($0)) }.joined(separator: "-") }
            return cap(w)
        }
        func cap(_ w: String) -> String {
            guard let f = w.first else { return w }
            var out = String(f).uppercased() + w.dropFirst()
            // McKittrick, McCarren
            if out.hasPrefix("Mc"), out.count > 3 { out = "Mc" + String(out.dropFirst(2).prefix(1)).uppercased() + out.dropFirst(3) }
            return out
        }
        let parts = s.split(separator: " ", omittingEmptySubsequences: false)
        return parts.enumerated().map { i, w in word(String(w), first: i == 0) }.joined(separator: " ")
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

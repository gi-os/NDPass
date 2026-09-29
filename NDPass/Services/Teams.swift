import UIKit

/// Team crests and colors from TheSportsDB, with your own key (Settings). Works for women's
/// leagues too: WNBA, NWSL, PWHL, AUSL, LOVB, Athletes Unlimited and the rest.
struct Team {
    var name: String
    var league: String
    var female: Bool
    var badge: URL?
    var colors: [UIColor]
}

enum Teams {
    /// Leagues that are women's even when TheSportsDB leaves the gender blank.
    static let womensLeagues = ["wnba", "nwsl", "pwhl", "ausl", "lovb", "athletes unlimited", "wpll", "unrivaled",
                                "women", "womens", "women's", "féminine", "liga f", "wsl"]
    /// Words on a ticket that say it's the women's team.
    static let womensCues = ["wnba", "nwsl", "pwhl", "women", "womens", "women's", "ladies", "(w)", " w "]

    static func isWomens(_ text: String) -> Bool {
        let t = " " + text.lowercased() + " "
        return womensCues.contains { t.contains($0) }
    }

    static func search(_ name: String, key: String) async -> [Team] {
        let cleaned = name.replacingOccurrences(of: #"(?i)\b(women'?s?|ladies|wnba|nwsl)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        var out = await query(cleaned, key: key)
        // "NY Liberty" / "Gotham" style short names: try the last word(s) if nothing matched.
        if out.isEmpty, let last = cleaned.split(separator: " ").last, last.count > 3 { out = await query(String(last), key: key) }
        return out
    }

    private static func query(_ q: String, key: String) async -> [Team] {
        guard !q.isEmpty, var c = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/\(key)/searchteams.php") else { return [] }
        c.queryItems = [URLQueryItem(name: "t", value: q)]
        guard let u = c.url, let (d, _) = try? await URLSession.shared.data(from: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let teams = j["teams"] as? [[String: Any]] else { return [] }
        return teams.map { t in
            let league = [t["strLeague"], t["strLeague2"]].compactMap { $0 as? String }.joined(separator: " ")
            let gender = (t["strGender"] as? String ?? "").lowercased()
            let female = gender == "female" || womensLeagues.contains { league.lowercased().contains($0) }
            let colors = ["strColour1", "strColour2", "strColour3"].compactMap { (t[$0] as? String).flatMap(color(hex:)) }
            let badge = (t["strBadge"] as? String ?? t["strTeamBadge"] as? String).flatMap(URL.init(string:))
            return Team(name: t["strTeam"] as? String ?? q, league: league, female: female, badge: badge, colors: colors)
        }
    }

    /// Both sides of a matchup, the same gender: the women's team when the ticket says so,
    /// or when only the women's side of one name exists; otherwise whichever both have.
    static func matchup(_ a: String, _ b: String, context: String, key: String) async -> (Team?, Team?) {
        async let ra = search(a, key: key)
        async let rb = search(b, key: key)
        let (la, lb) = await (ra, rb)
        var women = isWomens(context)
        if !women {
            let aw = la.contains { $0.female }, am = la.contains { !$0.female }
            let bw = lb.contains { $0.female }, bm = lb.contains { !$0.female }
            if (aw && !am) || (bw && !bm) { women = true }
            if aw && bw && !(am && bm) { women = true }
        }
        func pick(_ l: [Team]) -> Team? {
            let sameGender = l.filter { $0.female == women }
            return (sameGender.isEmpty ? l : sameGender).first
        }
        var ta = pick(la), tb = pick(lb)
        // Prefer the league the other side plays in, when the first pick disagrees.
        if let x = ta, let y = tb, x.league != y.league {
            if let alt = la.first(where: { $0.female == women && $0.league == y.league }) { ta = alt }
            else if let alt = lb.first(where: { $0.female == women && $0.league == x.league }) { tb = alt }
        }
        return (ta, tb)
    }

    static func badge(_ t: Team?) async -> UIImage? {
        guard let u = t?.badge else { return nil }
        let small = URL(string: u.absoluteString + "/medium") ?? u
        for url in [small, u] {
            if let (d, r) = try? await URLSession.shared.data(from: url), (r as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: d) { return img }
        }
        return nil
    }

    static func color(hex: String) -> UIColor? {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return UIColor(red: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

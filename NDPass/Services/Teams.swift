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

    /// City shorthand tickets use, spelled out the way TheSportsDB names teams.
    static let cities: [String: String] = [
        "ny": "New York", "nyc": "New York", "la": "Los Angeles", "lv": "Las Vegas", "gs": "Golden State",
        "kc": "Kansas City", "nc": "North Carolina", "sd": "San Diego", "dc": "Washington", "sf": "San Francisco",
        "conn": "Connecticut", "minn": "Minnesota", "indy": "Indiana", "phx": "Phoenix", "atl": "Atlanta",
        "chi": "Chicago", "sea": "Seattle", "tor": "Toronto", "mtl": "Montreal", "bos": "Boston", "ott": "Ottawa",
        "nj": "New Jersey", "philly": "Philadelphia", "pdx": "Portland", "slc": "Utah", "hou": "Houston",
    ]

    static func expand(_ name: String) -> String {
        name.split(separator: " ").map { w in cities[w.lowercased().trimmingCharacters(in: .punctuationCharacters)] ?? String(w) }.joined(separator: " ")
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            .split(separator: " ").map(String.init).filter { !["fc", "sc", "the", "of", "club", "cf"].contains($0) }
    }

    /// How well a team's name fits what the ticket says: the nickname (last word) counts
    /// most, then any shared words. 0 means no match.
    static func fit(_ ticket: String, _ team: String) -> Int {
        let a = words(expand(ticket)), b = words(team)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var s = Set(a).intersection(b).count * 2
        if let la = a.last, let lb = b.last, la == lb { s += 5 }
        if a == b { s += 10 }
        return s
    }

    static func search(_ name: String, key: String) async -> [Team] {
        let cleaned = expand(name.replacingOccurrences(of: #"(?i)\b(women'?s?|ladies|wnba|nwsl|pwhl)\b"#, with: "", options: .regularExpression))
            .trimmingCharacters(in: .whitespaces)
        var out = await query(cleaned, key: key)
        // Short names ("Liberty", "Gotham"): try the nickname alone too.
        if let last = cleaned.split(separator: " ").last, last.count > 3, String(last) != cleaned {
            out += await query(String(last), key: key)
        }
        return out.filter { fit(name, $0.name) > 0 }.sorted { fit(name, $0.name) > fit(name, $1.name) }
    }

    /// Women's leagues in the US and Canada, whole rosters, so a ticket's short name finds
    /// its team even when a men's or college team shares the nickname.
    static let womensRosterLeagues = ["WNBA", "American NWSL", "American PWHL"]
    private static var rosters: [Team]?

    static func womensRoster(key: String) async -> [Team] {
        if let r = rosters { return r }
        var all: [Team] = []
        for l in womensRosterLeagues {
            guard var c = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/\(key)/search_all_teams.php") else { continue }
            c.queryItems = [URLQueryItem(name: "l", value: l)]
            if let u = c.url { all += await teams(at: u, fallbackName: l).map { var t = $0; t.female = true; return t } }
        }
        rosters = all
        return all
    }

    private static func query(_ q: String, key: String) async -> [Team] {
        guard !q.isEmpty, var c = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/\(key)/searchteams.php") else { return [] }
        c.queryItems = [URLQueryItem(name: "t", value: q)]
        guard let u = c.url else { return [] }
        return await teams(at: u, fallbackName: q)
    }

    private static func teams(at u: URL, fallbackName q: String) async -> [Team] {
        guard let (d, _) = try? await URLSession.shared.data(from: u),
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
        async let rr = womensRoster(key: key)
        var (la, lb) = await (ra, rb)
        let roster = await rr
        // Women's teams from the league rosters, best fit first, ahead of anything else.
        func rosterHits(_ n: String) -> [Team] {
            roster.filter { fit(n, $0.name) >= 5 }.sorted { fit(n, $0.name) > fit(n, $1.name) }
        }
        let wa = rosterHits(a), wb = rosterHits(b)
        la = wa + la.filter { t in !wa.contains { $0.name == t.name } }
        lb = wb + lb.filter { t in !wb.contains { $0.name == t.name } }
        var women = isWomens(context) || (!wa.isEmpty && !wb.isEmpty)
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

    /// The crest's main color: the most common saturated hue, skipping white, black and
    /// grey. For teams the database lists without colors (most women's teams).
    static func mainColor(_ img: UIImage) -> UIColor? {
        let n = 24
        guard let cg = img.cgImage, let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let data = ctx.data else { return nil }
        let px = data.bindMemory(to: UInt8.self, capacity: n * n * 4)
        var buckets: [Int: (count: Int, r: CGFloat, g: CGFloat, b: CGFloat)] = [:]
        for i in 0..<(n * n) {
            let a = CGFloat(px[i * 4 + 3]) / 255
            guard a > 0.5 else { continue }
            let r = CGFloat(px[i * 4]) / 255 / a, g = CGFloat(px[i * 4 + 1]) / 255 / a, b = CGFloat(px[i * 4 + 2]) / 255 / a
            let c = UIColor(red: r, green: g, blue: b, alpha: 1)
            var h: CGFloat = 0, sat: CGFloat = 0, v: CGFloat = 0
            c.getHue(&h, saturation: &sat, brightness: &v, alpha: nil)
            guard sat > 0.3, v > 0.15 else { continue }
            let k = Int(h * 18)
            let e = buckets[k] ?? (0, 0, 0, 0)
            buckets[k] = (e.count + 1, e.r + r, e.g + g, e.b + b)
        }
        guard let top = buckets.values.max(by: { $0.count < $1.count }), top.count >= 6 else { return nil }
        let k = CGFloat(top.count)
        return UIColor(red: top.r / k, green: top.g / k, blue: top.b / k, alpha: 1)
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

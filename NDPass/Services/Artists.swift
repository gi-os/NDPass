import UIKit

/// Concert art: the artist's photo from Deezer's public catalog (no key), used only when the
/// name matches the ticket's exactly, so a ticket never gets someone else's face.
enum Artists {
    /// "Phoebe Bridgers – Reunion Tour", "Khruangbin: A LA SALA Tour", "Mitski with Gold Panda"
    /// → the headliner. Band names keep their numbers and ampersands ("The 1975",
    /// "Florence + the Machine", "Simon & Garfunkel").
    static func headliner(_ title: String) -> String {
        var t = title
        for sep in [" – ", " — ", " - ", ": ", " | ", " with ", " w/ ", " feat. ", " ft. ", " featuring ", " presents ", " plus special guest"] {
            if let r = t.range(of: sep, options: .caseInsensitive) { t = String(t[..<r.lowerBound]) }
        }
        // A tour or "live" tacked on the end ("Mitski Live", "Khruangbin World Tour 2026").
        t = t.replacingOccurrences(of: #"(?i)\s+(?:(?:the\s+)?(?:world|north american|us|uk|european)?\s*tour(?:\s+(?:19|20)\d{2})?|live(?:\s+in\s+concert)?|in concert)\s*$"#, with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:")))
    }

    /// Names compared without case, "the ", punctuation or "&"/"and" differences.
    static func same(_ a: String, _ b: String) -> Bool {
        func norm(_ s: String) -> String {
            var t = s.lowercased().replacingOccurrences(of: "&", with: " and ").replacingOccurrences(of: "+", with: " and ")
            if t.hasPrefix("the ") { t.removeFirst(4) }
            return t.filter { $0.isLetter || $0.isNumber }
        }
        let x = norm(a), y = norm(b)
        return !x.isEmpty && x == y
    }

    /// The artist's photo, full frame, from Deezer. Nil unless an artist with exactly the
    /// ticket's name is found (the most followed one, if several share it).
    static func photo(for title: String) async -> (name: String, image: UIImage)? {
        let who = headliner(title)
        guard !who.isEmpty, var c = URLComponents(string: "https://api.deezer.com/search/artist") else { return nil }
        c.queryItems = [URLQueryItem(name: "q", value: who), URLQueryItem(name: "limit", value: "10")]
        guard let u = c.url, let (d, _) = try? await URLSession.shared.data(from: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let list = j["data"] as? [[String: Any]] else { return nil }
        let best = list.filter { a in
            guard let pic = a["picture_xl"] as? String, !pic.contains("/artist//") else { return false }
            return same(a["name"] as? String ?? "", who)
        }.max { ($0["nb_fan"] as? Int ?? 0) < ($1["nb_fan"] as? Int ?? 0) }
        guard let best, let pic = best["picture_xl"] as? String, let pu = URL(string: pic),
              let (img, _) = try? await URLSession.shared.data(from: pu), let image = ImageKit.downsample(img, maxPixel: 1000) else { return nil }
        return (best["name"] as? String ?? who, image)
    }

    struct Hit: Identifiable {
        var id: Int
        var name: String
        var fans: Int
        var thumb: URL?
        var photo: URL?
    }

    /// Deezer artists for a name, most followed first, for picking by hand.
    static func search(_ q: String) async -> [Hit] {
        guard !q.isEmpty, var c = URLComponents(string: "https://api.deezer.com/search/artist") else { return [] }
        c.queryItems = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "limit", value: "20")]
        guard let u = c.url, let (d, _) = try? await URLSession.shared.data(from: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let list = j["data"] as? [[String: Any]] else { return [] }
        return list.compactMap { a in
            guard let pic = a["picture_xl"] as? String, !pic.contains("/artist//") else { return nil }
            return Hit(id: a["id"] as? Int ?? 0, name: a["name"] as? String ?? q, fans: a["nb_fan"] as? Int ?? 0,
                       thumb: (a["picture_medium"] as? String).flatMap(URL.init(string:)), photo: URL(string: pic))
        }
    }

}

/// Titles NDPass keeps: a game is "Team 1 vs Team 2", a concert is the band.
enum EventTitle {
    static func clean(_ title: String, kind: EventKind) -> String {
        switch kind {
        case .movie: return title
        case .sports:
            guard let (a, b) = Matchup.split(title) else { return title }
            func team(_ s: String) -> String {
                // Drop "NBA:", "Game 3", dates and "presented by" tails a stub adds around the names.
                var t = s.replacingOccurrences(of: #"(?i)^(nba|wnba|nfl|nhl|mlb|mls|nwsl|pwhl|ncaa)\s*[:\-–]\s*"#, with: "", options: .regularExpression)
                for sep in [" - ", " – ", " — ", ": ", " | ", " presented by ", " game ", " (", ","] {
                    if let r = t.range(of: sep, options: .caseInsensitive) { t = String(t[..<r.lowerBound]) }
                }
                return t.trimmingCharacters(in: .whitespaces)
            }
            let x = team(a), y = team(b)
            return x.isEmpty || y.isEmpty ? title : "\(x) vs \(y)"
        case .concert:
            let h = Artists.headliner(title)
            return h.isEmpty ? title : h
        case .theater, .event, .transit:
            return title
        }
    }
}

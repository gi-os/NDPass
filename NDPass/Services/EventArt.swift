import UIKit

/// Poster art for tickets that aren't films: two team crests cut across a diagonal for a
/// game, a drawn note for a concert. Best effort; any failure means the ticket shows its photo.
enum EventArt {
    static func logoURL(_ team: String) async -> URL? {
        guard var c = URLComponents(string: "https://site.web.api.espn.com/apis/search/v2") else { return nil }
        c.queryItems = [URLQueryItem(name: "query", value: team), URLQueryItem(name: "limit", value: "5")]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return nil }
        for r in results where r["type"] as? String == "team" {
            for item in r["contents"] as? [[String: Any]] ?? [] {
                guard let img = item["image"] as? [String: Any] else { continue }
                let s = (img["defaultDark"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? img["default"] as? String
                if let s, let u = URL(string: s) { return u }
            }
        }
        return nil
    }

    static func image(_ url: URL) async -> UIImage? {
        guard let (d, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: d)
    }

    static func art(for kind: EventKind, title: String) async -> Data? {
        switch kind {
        case .movie: return nil
        case .concert: return musicCard().pngData()
        case .sports:
            guard let (a, b) = Matchup.split(title) else { return nil }
            async let ua = logoURL(a)
            async let ub = logoURL(b)
            guard let la = await ua, let lb = await ub else { return nil }
            async let ia = image(la)
            async let ib = image(lb)
            guard let home = await ia, let away = await ib else { return nil }
            return versus(home, away).jpegData(compressionQuality: 0.9)
        }
    }

    static func versus(_ home: UIImage, _ away: UIImage) -> UIImage {
        let size = CGSize(width: 600, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.07, green: 0.07, blue: 0.13, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.12, green: 0.12, blue: 0.22, alpha: 1).setFill()
            c.move(to: .zero); c.addLine(to: CGPoint(x: size.width, y: 0)); c.addLine(to: CGPoint(x: 0, y: size.height)); c.closePath(); c.fillPath()
            home.draw(in: CGRect(x: 40, y: 80, width: 320, height: 320))
            away.draw(in: CGRect(x: 240, y: 500, width: 320, height: 320))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 56, weight: .black), .foregroundColor: UIColor(red: 0.91, green: 0.84, blue: 0.72, alpha: 1)]
            ("VS" as NSString).draw(at: CGPoint(x: 400, y: 330), withAttributes: attrs)
        }
    }

    static func musicCard() -> UIImage {
        let size = CGSize(width: 600, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
            let cfg = UIImage.SymbolConfiguration(pointSize: 300, weight: .bold)
            if let note = UIImage(systemName: "music.note", withConfiguration: cfg)?.withTintColor(UIColor(red: 0.91, green: 0.84, blue: 0.72, alpha: 1), renderingMode: .alwaysOriginal) {
                note.draw(in: CGRect(x: 150, y: 250, width: 300, height: 400))
            }
        }
    }
}

import UIKit

/// Concert art from Apple's iTunes Search API (no key): the headliner's most popular album
/// cover. Apple's catalog has no artist photos, so the record stands in for the act.
enum Artists {
    /// "Phoebe Bridgers – Reunion Tour", "Khruangbin: A LA SALA Tour", "Mitski with Gold Panda"
    /// → the headliner.
    static func headliner(_ title: String) -> String {
        var t = title
        for sep in [" – ", " — ", " - ", ": ", " | ", " with ", " w/ ", " feat. ", " ft. ", " + ", " presents "] {
            if let r = t.range(of: sep, options: .caseInsensitive) { t = String(t[..<r.lowerBound]) }
        }
        t = t.replacingOccurrences(of: #"(?i)\b(live|in concert|tour|world tour|\d{4})\b"#, with: "", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:")))
    }

    static func cover(for title: String) async -> (name: String, image: UIImage)? {
        let who = headliner(title)
        guard !who.isEmpty, var c = URLComponents(string: "https://itunes.apple.com/search") else { return nil }
        c.queryItems = [URLQueryItem(name: "term", value: who), URLQueryItem(name: "entity", value: "album"),
                        URLQueryItem(name: "attribute", value: "artistTerm"), URLQueryItem(name: "limit", value: "5"),
                        URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US")]
        guard let u = c.url, let (d, _) = try? await URLSession.shared.data(from: u),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let results = j["results"] as? [[String: Any]] else { return nil }
        // The artist whose name matches best, skipping singles and compilations.
        let key = who.lowercased()
        let ranked = results.sorted { a, b in
            func score(_ r: [String: Any]) -> Int {
                let n = (r["artistName"] as? String ?? "").lowercased()
                var s = n == key ? 0 : (n.contains(key) || key.contains(n) ? 1 : 3)
                if (r["collectionName"] as? String ?? "").localizedCaseInsensitiveContains("single") { s += 1 }
                if (r["collectionType"] as? String) == "Compilation" { s += 2 }
                return s
            }
            return score(a) < score(b)
        }
        guard let best = ranked.first, let art = best["artworkUrl100"] as? String,
              let big = URL(string: art.replacingOccurrences(of: "100x100bb", with: "1200x1200bb")),
              let (img, _) = try? await URLSession.shared.data(from: big), let image = UIImage(data: img) else { return nil }
        return (best["artistName"] as? String ?? who, image)
    }

    /// The cover sharp in the middle of itself, blurred and darkened, square.
    static func card(_ cover: UIImage) -> UIImage {
        let size = CGSize(width: 1000, height: 1000)
        let blurred: UIImage = {
            guard let ci = CIImage(image: cover) else { return cover }
            let f = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: ci.clampedToExtent(), kCIInputRadiusKey: 40])
            guard let out = f?.outputImage?.cropped(to: ci.extent), let cg = CIContext().createCGImage(out, from: ci.extent) else { return cover }
            return UIImage(cgImage: cg)
        }()
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            blurred.draw(in: CGRect(origin: .zero, size: size))
            UIColor.black.withAlphaComponent(0.35).setFill(); c.fill(CGRect(origin: .zero, size: size))
            let r = CGRect(x: 230, y: 230, width: 540, height: 540)
            c.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: UIColor.black.withAlphaComponent(0.55).cgColor)
            cover.draw(in: r)
        }
    }
}

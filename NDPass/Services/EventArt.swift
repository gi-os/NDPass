import UIKit

/// Poster art for tickets that aren't films: two team crests cut across a diagonal for a
/// game, a drawn note for a concert. Best effort; any failure means the ticket shows its photo.
enum EventArt {
    /// Art for a game or concert, and the proper name while we're at it: the teams as the
    /// league spells them, the artist as they're billed.
    static func decorate(_ p: Pass) async {
        guard p.kind != .movie else { return }
        let (data, name) = await artAndName(for: p.kind, title: p.title, context: p.venue)
        if let data { p.art = data }
        if let name, !name.isEmpty { p.title = name }
        else if p.title == p.title.lowercased(), let t = PassTimes.titleCase(p.title) { p.title = t }
    }

    static func art(for kind: EventKind, title: String, context: String = "") async -> Data? {
        await artAndName(for: kind, title: title, context: context).0
    }

    static func artAndName(for kind: EventKind, title: String, context: String) async -> (Data?, String?) {
        switch kind {
        case .movie: return (nil, nil)
        case .concert:
            // The artist's photo, full frame.
            if let hit = await Artists.photo(for: title) { return (hit.image.jpegData(compressionQuality: 0.88), hit.name) }
            return (musicCard().pngData(), nil)
        case .sports:
            guard let (a, b) = Matchup.split(title) else { return (nil, nil) }
            // With a TheSportsDB key: each team's crest on its own color. Without one, or if a
            // team isn't found, its name set in type on that side.
            if let key = Keys.get(.sportsdb) {
                let (ta, tb) = await Teams.matchup(a, b, context: title + " " + context, key: key)
                if ta != nil || tb != nil {
                    async let ia = Teams.badge(ta)
                    async let ib = Teams.badge(tb)
                    let (ba, bb) = await (ia, ib)
                    func colors(_ t: Team?, _ img: UIImage?) -> [UIColor] {
                        if let cs = t?.colors, !cs.isEmpty { return cs }
                        return img.flatMap(Teams.mainColor).map { [$0] } ?? []
                    }
                    let img = split(home: (ta?.name ?? a, ba, colors(ta, ba)), away: (tb?.name ?? b, bb, colors(tb, bb)), seed: title)
                    return (img.jpegData(compressionQuality: 0.9), "\(ta?.name ?? a) vs \(tb?.name ?? b)")
                }
            }
            return (matchCard(a, b).jpegData(compressionQuality: 0.9), nil)
        }
    }

    /// A square cut on the diagonal: the home side in its color with its crest top-left, the
    /// away side in theirs bottom-right. Square so it crops well as a poster or a banner.
    static func split(home: (String, UIImage?, [UIColor]), away: (String, UIImage?, [UIColor]), seed: String) -> UIImage {
        let size = CGSize(width: 1000, height: 1000)
        let warm = [UIColor(red: 0.94, green: 0.54, blue: 0.24, alpha: 1), UIColor(red: 0.35, green: 0.18, blue: 0.09, alpha: 1)]
        func base(_ cs: [UIColor], fallback: UIColor) -> UIColor {
            // Skip near-white and near-black so the crest has something to sit on.
            let usable = cs.first { c in var w: CGFloat = 0; c.getWhite(&w, alpha: nil); return w > 0.1 && w < 0.9 }
            return usable ?? cs.first ?? fallback
        }
        let ca = base(home.2, fallback: warm[0]), cb = base(away.2, fallback: warm[1])
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            func fill(_ color: UIColor, _ pts: [CGPoint]) {
                c.saveGState()
                c.move(to: pts[0]); pts.dropFirst().forEach { c.addLine(to: $0) }; c.closePath(); c.clip()
                let dark = color.blended(with: .black, 0.45)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color.cgColor, dark.cgColor] as CFArray, locations: [0, 1])!
                c.drawLinearGradient(g, start: pts[0], end: pts[2], options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                c.restoreGState()
            }
            fill(ca, [.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height)])
            fill(cb, [CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: 0)])
            // The seam.
            c.setStrokeColor(UIColor.black.withAlphaComponent(0.35).cgColor); c.setLineWidth(6)
            c.move(to: CGPoint(x: size.width, y: 0)); c.addLine(to: CGPoint(x: 0, y: size.height)); c.strokePath()

            func crest(_ side: (String, UIImage?, [UIColor]), center: CGPoint, color: UIColor) {
                let box = CGRect(x: center.x - 150, y: center.y - 150, width: 300, height: 300)
                if let img = side.1 {
                    let s = min(box.width / img.size.width, box.height / img.size.height)
                    let r = CGRect(x: center.x - img.size.width * s / 2, y: center.y - img.size.height * s / 2, width: img.size.width * s, height: img.size.height * s)
                    c.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: UIColor.black.withAlphaComponent(0.45).cgColor)
                    img.draw(in: r)
                    c.setShadow(offset: .zero, blur: 0, color: nil)
                } else {
                    var w: CGFloat = 0; color.getWhite(&w, alpha: nil)
                    let ink: UIColor = w > 0.6 ? UIColor(red: 0.11, green: 0.05, blue: 0.02, alpha: 1) : UIColor(red: 0.96, green: 0.91, blue: 0.85, alpha: 1)
                    let p = NSMutableParagraphStyle(); p.alignment = .center
                    let font = UIFont(name: "InstrumentSerif-Regular", size: 84) ?? .systemFont(ofSize: 72, weight: .black)
                    (side.0 as NSString).draw(with: box, options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: p], context: nil)
                }
            }
            crest(home, center: CGPoint(x: 320, y: 400), color: ca)
            crest(away, center: CGPoint(x: 680, y: 600), color: cb)
        }
    }

    static func matchCard(_ home: String, _ away: String) -> UIImage {
        let size = CGSize(width: 600, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.94, green: 0.54, blue: 0.24, alpha: 1).setFill()
            c.move(to: .zero); c.addLine(to: CGPoint(x: size.width, y: 0)); c.addLine(to: CGPoint(x: 0, y: size.height)); c.closePath(); c.fillPath()
            let cream = UIColor(red: 0.96, green: 0.91, blue: 0.85, alpha: 1)
            let ink = UIColor(red: 0.11, green: 0.05, blue: 0.02, alpha: 1)
            func draw(_ s: String, _ r: CGRect, _ color: UIColor, _ align: NSTextAlignment) {
                let p = NSMutableParagraphStyle(); p.alignment = align
                let font = UIFont(name: "InstrumentSerif-Regular", size: 92) ?? .systemFont(ofSize: 80, weight: .black)
                (s as NSString).draw(with: r, options: [.usesLineFragmentOrigin], attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p], context: nil)
            }
            draw(home, CGRect(x: 40, y: 90, width: 520, height: 320), ink, .left)
            draw(away, CGRect(x: 40, y: 520, width: 520, height: 320), cream, .right)
            let vs: [NSAttributedString.Key: Any] = [.font: UIFont(name: "InstrumentSerif-Italic", size: 70) ?? .italicSystemFont(ofSize: 60), .foregroundColor: cream]
            ("vs" as NSString).draw(at: CGPoint(x: 420, y: 400), withAttributes: vs)
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

private extension UIColor {
    func blended(with other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1); other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}

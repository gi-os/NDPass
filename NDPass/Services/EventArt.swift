import UIKit

/// Poster art for tickets that aren't films: two team crests cut across a diagonal for a
/// game, a drawn note for a concert. Best effort; any failure means the ticket shows its photo.
enum EventArt {
    static func art(for kind: EventKind, title: String) async -> Data? {
        switch kind {
        case .movie: return nil
        case .concert: return musicCard().pngData()
        case .sports:
            // Team names set as a versus card. (Crests came from ESPN's unofficial API, which
            // isn't something to ship in a store app.)
            guard let (a, b) = Matchup.split(title) else { return nil }
            return matchCard(a, b).jpegData(compressionQuality: 0.9)
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

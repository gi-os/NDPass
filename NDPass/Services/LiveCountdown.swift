import ActivityKit
import SwiftUI
import UIKit

/// The Lock Screen and Dynamic Island countdown, from 30 minutes before a showing. On iOS 26
/// it's scheduled ahead and starts by itself; before that it starts when NDPass is opened in
/// the last 30 minutes (the 30-minute reminder brings you there). Twenty minutes out it goes
/// stale and redraws as the door card; ten minutes after the start it ends.
@MainActor
enum LiveCountdown {
    static let lead: TimeInterval = 30 * 60
    static let linger: TimeInterval = 10 * 60
    static let ahead = 3            // showings scheduled at once (iOS 26)

    static func refresh(_ passes: [Pass]) async {
        guard !Demo.active else { return }
        let now = Date()
        let upcoming = Showings.groups(passes, archived: false).filter { g in
            guard let s = g[0].start else { return false }
            return now <= s + linger
        }
        var wanted: [[Pass]]
        if #available(iOS 26.0, *) {
            wanted = Array(upcoming.prefix(ahead))
        } else {
            wanted = upcoming.filter { g in g[0].start.map { $0 - lead <= now } ?? false }.prefix(1).map { $0 }
        }
        let keys = Set(wanted.map { $0[0].group.uuidString })
        for a in Activity<CountdownAttributes>.activities {
            let stillWanted = keys.contains(a.attributes.group)
            let moved = wanted.first { $0[0].group.uuidString == a.attributes.group }?[0].start.map { $0 != a.content.state.start } ?? false
            if !stillWanted || moved { await a.end(nil, dismissalPolicy: .immediate) }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for g in wanted {
            guard let p = g.first, let start = p.start else { continue }
            let key = p.group.uuidString
            if Activity<CountdownAttributes>.activities.contains(where: { $0.attributes.group == key && $0.activityState != .ended && $0.activityState != .dismissed }) { continue }
            await saveArt(g, key: key)
            let content = ActivityContent(state: CountdownAttributes.ContentState(start: start),
                                          staleDate: start - 20 * 60, relevanceScore: 100)
            let attrs = attributes(g, start: start)
            let begin = start - lead
            if #available(iOS 26.0, *), begin > now.addingTimeInterval(60) {
                let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: p.title),
                                               body: LocalizedStringResource(stringLiteral: "Starts in 30 minutes" + (p.venue.isEmpty ? "" : " at \(p.venue)")),
                                               sound: .default)
                _ = try? Activity.request(attributes: attrs, content: content, pushType: nil, style: .standard, alertConfiguration: alert, start: begin)
            } else if begin <= now {
                _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
            }
        }
    }

    private static func attributes(_ g: [Pass], start: Date) -> CountdownAttributes {
        let p = g[0]
        let h = Calendar.current.component(.hour, from: start)
        let day = Calendar.current.isDateInToday(start) ? (h >= 17 ? "TONIGHT" : "TODAY")
            : Calendar.current.isDateInTomorrow(start) ? "TOMORROW" : start.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        return CountdownAttributes(
            group: p.group.uuidString, title: p.title, venue: p.venue, time: p.time,
            seats: g.map(\.seat).filter { !$0.isEmpty },
            eyebrow: p.venue.isEmpty ? day : "\(day) · \(p.venue.uppercased())",
            windowStart: start - lead,
            seller: (p.seller?.rotatingCode == true) ? p.seller?.name : nil)
    }

    /// The activity can't download anything, so the pictures go into the App Group first,
    /// small enough for its memory limit.
    private static func saveArt(_ g: [Pass], key: String) async {
        guard let dir = CountdownArt.folder(key) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let p = g[0]
        var backdrop: UIImage?
        if let u = p.backdropURL, let (d, _) = try? await URLSession.shared.data(from: u) { backdrop = UIImage(data: d) }
        if backdrop == nil, let d = p.art { backdrop = UIImage(data: d) }
        // Live Activities only draw small images; a big one comes out as a grey box.
        if let b = backdrop.flatMap({ shrink($0, width: 600) }), let d = b.jpegData(compressionQuality: 0.7), let u = CountdownArt.backdrop(key) { try? d.write(to: u) }
        var logo: UIImage?
        if let lu = p.logoURL, let (d, _) = try? await URLSession.shared.data(from: lu), let img = UIImage(data: d) {
            logo = shrink(img, width: 300)
            if let png = logo?.pngData(), let u = CountdownArt.logo(key) { try? png.write(to: u) }
        }
        if let png = island(backdrop: backdrop, logo: logo, title: p.title).pngData(), let u = CountdownArt.island(key) { try? png.write(to: u) }
        if p.seller?.rotatingCode != true, let code = codeImage(p), let png = code.pngData(), let u = CountdownArt.code(key) { try? png.write(to: u) }
    }

    /// 64×40 points at 3x: the backdrop darkened a little with the film's logo (or title) on it.
    private static func island(backdrop: UIImage?, logo: UIImage?, title: String) -> UIImage {
        let size = CGSize(width: 192, height: 120)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let r = CGRect(origin: .zero, size: size)
            UIColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 1).setFill(); ctx.fill(r)
            if let b = backdrop {
                let s = max(size.width / b.size.width, size.height / b.size.height)
                let w = b.size.width * s, h = b.size.height * s
                b.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
                UIColor.black.withAlphaComponent(0.3).setFill(); ctx.fill(r)
            }
            if let l = logo {
                let box = r.insetBy(dx: 14, dy: 22)
                let s = min(box.width / l.size.width, box.height / l.size.height)
                let w = l.size.width * s, h = l.size.height * s
                l.draw(in: CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h))
            } else {
                let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineBreakMode = .byTruncatingTail
                let font = UIFont(name: "InstrumentSerif-Regular", size: 30) ?? .systemFont(ofSize: 26, weight: .bold)
                (title as NSString).draw(with: r.insetBy(dx: 10, dy: 30), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                         attributes: [.font: font, .foregroundColor: UIColor(red: 0.96, green: 0.91, blue: 0.85, alpha: 1), .paragraphStyle: p], context: nil)
            }
        }
    }

    private static func codeImage(_ p: Pass) -> UIImage? {
        if let s = p.scannedCode, let f = p.scannedFormat, let img = Barcodes.render(s, as: f) { return img }
        return nil
    }

    private static func shrink(_ img: UIImage, width: CGFloat) -> UIImage {
        guard img.size.width > width else { return img }
        let size = CGSize(width: width, height: (img.size.height * width / img.size.width).rounded())
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// Buttons on the Lock Screen and Dynamic Island come back as ndpass:// links.
struct CountdownLink {
    enum Action: String { case ticket, door, seller, directions }
    let action: Action
    let group: UUID

    init?(_ url: URL) {
        guard url.scheme == "ndpass", let a = Action(rawValue: url.host ?? ""),
              let g = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "group" })?.value,
              let id = UUID(uuidString: g) else { return nil }
        action = a; group = id
    }
}

import ActivityKit
import SwiftUI
import UIKit

/// The Lock Screen and Dynamic Island countdown, from 30 minutes before a showing (90 before a flight). On iOS 26
/// it's scheduled ahead and starts by itself; before that it starts when NDPass is opened in
/// the last 30 minutes (the 30-minute reminder brings you there). Twenty minutes out it goes
/// stale and redraws as the door card; ten minutes after the start it ends.
@MainActor
enum LiveCountdown {
    static let lead: TimeInterval = 30 * 60
    /// Flights board well before they leave; everything else starts the countdown at 30 min.
    static func leadTime(_ p: Pass) -> TimeInterval { p.kind == .transit && p.transitMode == .flight ? 90 * 60 : lead }
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
            wanted = upcoming.filter { g in g[0].start.map { $0 - leadTime(g[0]) <= now } ?? false }.prefix(1).map { $0 }
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
            if let running = Activity<CountdownAttributes>.activities.first(where: { $0.attributes.group == key && $0.activityState != .ended && $0.activityState != .dismissed }) {
                // Started by an older build (its codes were too big to draw): redo the
                // pictures and nudge it to redraw.
                if !artIsCurrent(key) { await saveArt(g, key: key); await running.update(running.content) }
                continue
            }
            await saveArt(g, key: key)
            let transit = p.kind == .transit
            // Trips show the boarding pass for the whole window, so they never go stale early.
            let content = ActivityContent(state: CountdownAttributes.ContentState(start: start, index: 0),
                                          staleDate: transit ? start + linger : start - 20 * 60, relevanceScore: 100)
            let attrs = attributes(g, start: start)
            let begin = start - leadTime(p)
            if #available(iOS 26.0, *), begin > now.addingTimeInterval(60) {
                let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: p.title),
                                               body: LocalizedStringResource(stringLiteral: (transit ? "Departs in \(Int(leadTime(p) / 60)) minutes" : "Starts in 30 minutes") + (p.venue.isEmpty ? "" : (transit ? " from " : " at ") + p.venue)),
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
        let transit = p.kind == .transit
        let gate = p.gate.isEmpty ? nil : (p.gate.first?.isNumber == true || p.gate.count <= 3 ? "\(p.transitMode.gateLabel) \(p.gate)" : p.gate)
        let place = transit ? p.kindLine : p.venue.uppercased()
        return CountdownAttributes(
            group: p.group.uuidString, title: p.title, venue: p.venue, time: p.time,
            seats: g.map(\.seat),
            eyebrow: place.isEmpty ? day : "\(day) · \(place)",
            windowStart: start - leadTime(p),
            seller: (p.seller?.rotatingCode == true) ? p.seller?.name : nil,
            kind: p.kind.rawValue,
            gate: gate,
            destination: p.destination.isEmpty ? nil : p.destination)
    }

    /// Bumped whenever the saved pictures change shape. v2: Lock Screen-sized codes, one per ticket.
    private static let artVersion = "v2"
    private static func artIsCurrent(_ key: String) -> Bool {
        CountdownArt.folder(key).map { FileManager.default.fileExists(atPath: $0.appendingPathComponent(artVersion).path) } ?? true
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
        // One code per ticket, small enough for the Lock Screen (see Barcodes.render).
        if p.seller?.rotatingCode != true {
            for (i, t) in g.enumerated() {
                guard let u = CountdownArt.code(key, i) else { continue }
                if let png = codeImage(t)?.pngData() { try? png.write(to: u) } else { try? FileManager.default.removeItem(at: u) }
            }
        }
        FileManager.default.createFile(atPath: dir.appendingPathComponent(artVersion).path, contents: Data())
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

    /// The code tile is ~100 pt on the Lock Screen: 3x that, and never more than the card.
    static let codePixels: CGFloat = 300

    private static func codeImage(_ p: Pass) -> UIImage? {
        if let s = p.scannedCode, let f = p.scannedFormat, let img = Barcodes.render(s, as: f, fit: codePixels) { return img }
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

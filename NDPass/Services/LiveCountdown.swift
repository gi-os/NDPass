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

    private static var running = false
    private static var again = false

    /// Bring the Live Activities in line with the tickets. Safe to call often: one refresh
    /// runs at a time, and a call that comes in meanwhile runs once more afterwards (so
    /// pulling down Notification Center can't start two of the same).
    static func refresh(_ passes: [Pass]) async {
        guard !Demo.active else { return }
        if running { again = true; return }
        running = true
        defer { running = false }
        repeat {
            again = false
            await refreshOnce(passes.filter { !$0.isDeleted })
        } while again
    }

    /// Showings you swiped off the Lock Screen: not brought back.
    private static let dismissedKey = "liveDismissed"
    /// Activities NDPass ended itself (a ticket changed): not mistaken for a swipe.
    private static let endedKey = "liveEndedByUs"

    private static func refreshOnce(_ passes: [Pass]) async {
        let now = Date()
        let upcoming = Showings.groups(passes, archived: false).filter { g in
            guard let s = g[0].start else { return false }
            return now <= s + linger
        }
        var wanted: [[Pass]]
        if #available(iOS 26.0, *) {
            wanted = Array(upcoming.prefix(ahead))
        } else {
            wanted = upcoming.filter { g in g[0].start.map { $0 - leadTime(g[0]) <= now.addingTimeInterval(60) } ?? false }.prefix(1).map { $0 }
        }
        let d = Store.defaults
        var dismissed = Set(d.stringArray(forKey: dismissedKey) ?? []).intersection(upcoming.map { $0[0].group.uuidString })
        let plans = Dictionary(wanted.compactMap { g -> (String, (CountdownAttributes, Date))? in
            guard let start = g[0].start else { return nil }
            return (g[0].group.uuidString, (attributes(g, start: start), start))
        }, uniquingKeysWith: { a, _ in a })

        var endedByUs = Set(d.stringArray(forKey: endedKey) ?? [])
        func end(_ a: Activity<CountdownAttributes>) async {
            endedByUs.insert(a.id)
            await a.end(nil, dismissalPolicy: .immediate)
        }
        for a in Activity<CountdownAttributes>.activities {
            let key = a.attributes.group
            guard let (attrs, start) = plans[key] else {
                if a.activityState != .ended && a.activityState != .dismissed { await end(a) }
                continue
            }
            if a.activityState == .dismissed || a.activityState == .ended {
                // Gone from the Lock Screen without NDPass ending it: you swiped it away.
                if !endedByUs.contains(a.id) { dismissed.insert(key) }
                continue
            }
            // A changed time, title, venue or seat: start again with the new details.
            if a.content.state.start != start || a.attributes.title != attrs.title || a.attributes.venue != attrs.venue
                || a.attributes.seats != attrs.seats || a.attributes.place != attrs.place || a.attributes.gate != attrs.gate {
                await end(a)
            }
        }
        d.set(Array(dismissed), forKey: dismissedKey)
        // Only remember ids of activities that still exist.
        let ids = Set(Activity<CountdownAttributes>.activities.map(\.id))
        d.set(Array(endedByUs.intersection(ids)), forKey: endedKey)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for g in wanted {
            guard let p = g.first, !p.isDeleted, let start = p.start else { continue }
            let key = p.group.uuidString
            if dismissed.contains(key) { continue }
            if let live = Activity<CountdownAttributes>.activities.first(where: { $0.attributes.group == key && $0.activityState != .ended && $0.activityState != .dismissed }) {
                // Started by an older build (its codes were too big to draw): redo the
                // pictures and nudge it to redraw.
                if !artIsCurrent(key) { await saveArt(ArtInput(g), key: key); await live.update(live.content) }
                continue
            }
            guard let (attrs, _) = plans[key] else { continue }
            let transit = p.kind == .transit
            let lead = leadTime(p)
            let title = p.title, venue = p.venue
            // Everything read from the tickets is copied before the first wait: a ticket
            // deleted meanwhile can't be touched afterwards.
            let input = ArtInput(g)
            await saveArt(input, key: key)
            // Trips show the boarding pass for the whole window, so they never go stale early.
            let content = ActivityContent(state: CountdownAttributes.ContentState(start: start, index: 0),
                                          staleDate: transit ? start + linger : start - 20 * 60, relevanceScore: 100)
            let begin = start - lead
            if #available(iOS 26.0, *), begin > Date().addingTimeInterval(60) {
                let body = (transit ? "Departs in \(Int(lead / 60)) minutes" : "Starts in 30 minutes") + (venue.isEmpty ? "" : (transit ? " from " : " at ") + venue)
                let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: title), body: LocalizedStringResource(stringLiteral: body), sound: .default)
                _ = try? Activity.request(attributes: attrs, content: content, pushType: nil, style: .standard, alertConfiguration: alert, start: begin)
            } else {
                // In the window already, or within the minute: start now.
                _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
            }
        }
        cleanUp(keep: Set(upcoming.map { $0[0].group.uuidString }))
    }

    /// Pictures for showings that are over are deleted.
    private static func cleanUp(keep: Set<String>) {
        guard let root = Store.folder?.appendingPathComponent("Countdown", isDirectory: true),
              let dirs = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        let live = Set(Activity<CountdownAttributes>.activities.filter { $0.activityState != .dismissed && $0.activityState != .ended }.map(\.attributes.group))
        for dir in dirs where !keep.contains(dir.lastPathComponent) && !live.contains(dir.lastPathComponent) {
            try? FileManager.default.removeItem(at: dir)
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
            destination: p.destination.isEmpty ? nil : p.destination,
            place: place)
    }

    /// Bumped whenever the saved pictures change shape. v2: Lock Screen-sized codes, one per ticket.
    private static let artVersion = "v2"
    private static func artIsCurrent(_ key: String) -> Bool {
        CountdownArt.folder(key).map { FileManager.default.fileExists(atPath: $0.appendingPathComponent(artVersion).path) } ?? true
    }

    /// What the pictures need from the tickets, copied up front.
    struct ArtInput {
        let backdropURL: URL?, logoURL: URL?, art: Data?, title: String, rotating: Bool, codes: [UIImage?]
        @MainActor init(_ g: [Pass]) {
            let p = g[0]
            backdropURL = p.backdropURL; logoURL = p.logoURL; art = p.art; title = p.title
            rotating = p.seller?.rotatingCode == true
            codes = rotating ? [] : g.map { LiveCountdown.codeImage($0) }
        }
    }

    /// The activity can't download anything, so the pictures go into the App Group first,
    /// small enough for its memory limit.
    private static func saveArt(_ input: ArtInput, key: String) async {
        guard let dir = CountdownArt.folder(key) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var backdrop: UIImage?
        if let u = input.backdropURL, let (d, _) = try? await URLSession.shared.data(from: u) { backdrop = ImageKit.downsample(d, maxPixel: 600) }
        if backdrop == nil, let d = input.art { backdrop = ImageKit.downsample(d, maxPixel: 600) }
        // Live Activities only draw small images; a big one comes out as a grey box.
        if let b = backdrop, let d = b.jpegData(compressionQuality: 0.7), let u = CountdownArt.backdrop(key) { try? d.write(to: u) }
        else if let u = CountdownArt.backdrop(key) { try? FileManager.default.removeItem(at: u) }
        var logo: UIImage?
        if let lu = input.logoURL, let (d, _) = try? await URLSession.shared.data(from: lu) { logo = ImageKit.downsample(d, maxPixel: 300) }
        if let png = logo?.pngData(), let u = CountdownArt.logo(key) { try? png.write(to: u) }
        else if let u = CountdownArt.logo(key) { try? FileManager.default.removeItem(at: u) }   // the film changed
        if let png = island(backdrop: backdrop, logo: logo, title: input.title).pngData(), let u = CountdownArt.island(key) { try? png.write(to: u) }
        // One code per ticket, small enough for the Lock Screen (see Barcodes.render).
        if !input.rotating {
            for (i, code) in input.codes.enumerated() {
                guard let u = CountdownArt.code(key, i) else { continue }
                if let png = code?.pngData() { try? png.write(to: u) } else { try? FileManager.default.removeItem(at: u) }
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

    static func codeImage(_ p: Pass) -> UIImage? {
        if let s = p.scannedCode, let f = p.scannedFormat, let img = Barcodes.render(s, as: f, fit: codePixels) { return img }
        return nil
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

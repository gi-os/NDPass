import ActivityKit
import SwiftUI
import UIKit

/// Starts the Lock Screen countdown when the next showing is within four hours. There's no
/// push server, so it starts when NDPass comes to the front (the two-hour reminder brings it
/// there). Twenty minutes out it goes stale and redraws as the door card; ten minutes after
/// the start it ends.
@MainActor
enum LiveCountdown {
    static let lead: TimeInterval = 4 * 3600
    static let linger: TimeInterval = 10 * 60

    static func refresh(_ passes: [Pass]) async {
        guard !Demo.active else { return }
        let now = Date()
        let next = Showings.groups(passes, archived: false).first { g in
            guard let s = g[0].start else { return false }
            return s - lead <= now && now <= s + linger
        }
        let key = next?[0].group.uuidString
        for a in Activity<CountdownAttributes>.activities where a.attributes.group != key || next == nil {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        guard let g = next, let p = g.first, let start = p.start, let key,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(state: CountdownAttributes.ContentState(start: start),
                                      staleDate: start - 20 * 60, relevanceScore: 100)
        if let live = Activity<CountdownAttributes>.activities.first(where: { $0.attributes.group == key }) {
            if live.content.state.start != start { await live.update(content) }
            return
        }
        await saveArt(g, key: key)
        let h = Calendar.current.component(.hour, from: start)
        let day = Calendar.current.isDateInToday(start) ? (h >= 17 ? "TONIGHT" : "TODAY") : "TOMORROW"
        let attrs = CountdownAttributes(
            group: key, title: p.title, venue: p.venue, time: p.time,
            seats: g.map(\.seat).filter { !$0.isEmpty },
            eyebrow: p.venue.isEmpty ? day : "\(day) · \(p.venue.uppercased())",
            windowStart: start - lead,
            seller: (p.seller?.rotatingCode == true) ? p.seller?.name : nil)
        _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
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
        if let b = backdrop.flatMap({ shrink($0, width: 700) }), let d = b.jpegData(compressionQuality: 0.72), let u = CountdownArt.backdrop(key) { try? d.write(to: u) }
        if let lu = p.logoURL, let (d, _) = try? await URLSession.shared.data(from: lu), let img = UIImage(data: d),
           let png = shrink(img, width: 360).pngData(), let u = CountdownArt.logo(key) {
            try? png.write(to: u)
        }
        if p.seller?.rotatingCode != true, let code = codeImage(p), let png = code.pngData(), let u = CountdownArt.code(key) { try? png.write(to: u) }
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

import SwiftUI
import UIKit
import WidgetKit

/// Keeps the Home Screen widget's list of upcoming films (and their posters) in the App Group,
/// and asks WidgetKit to redraw when it changes.
@MainActor
enum FilmWidget {
    /// Films written at once, so the widget can move on to the next one after a showing ends
    /// without NDPass being opened.
    static let ahead = 4

    private static var running = false
    private static var again = false

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

    private static func refreshOnce(_ passes: [Pass]) async {
        let now = Date()
        let groups = Showings.groups(passes.filter { $0.kind == .movie }, archived: false)
        // Everything read from the tickets is copied before the first wait.
        let picked: [(NextFilm, URL?, URL?, Data?)] = groups.compactMap { g -> (NextFilm, URL?, URL?, Data?)? in
            let p = g[0]
            guard let start = p.start else { return nil }
            let ends = start.addingTimeInterval(TimeInterval((p.runtime ?? 180) * 60))
            guard ends > now else { return nil }
            let film = NextFilm(group: p.group.uuidString, title: p.title, venue: p.venue, start: start, ends: ends,
                                time: p.time, seats: g.map(\.seat).filter { !$0.isEmpty }, tickets: g.count,
                                runtime: p.runtime, posterPath: p.posterPath, logoPath: p.logoPath)
            return (film, p.posterURL, p.logoURL, p.art ?? p.crop)
        }
        .prefix(ahead).map { $0 }

        let saved = NextFilmStore.read()
        let old = Dictionary(saved.map { ($0.group, $0) }, uniquingKeysWith: { a, _ in a })
        let films = picked.map(\.0)
        let fm = FileManager.default
        var artChanged = false
        if let dir = NextFilmStore.folder { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        for (film, posterURL, logoURL, art) in picked {
            let g = film.group
            let before = old[g]
            // Poster: TMDb's, else the ticket's own art. Fetched for a new film, when the poster
            // changed, or again when the last download didn't make it.
            if let u = NextFilmStore.poster(g), before == nil || before?.posterPath != film.posterPath
                || (film.posterPath != nil && !fm.fileExists(atPath: u.path)) {
                artChanged = true
                var img: UIImage?
                if let pu = posterURL, let (d, _) = try? await URLSession.shared.data(from: pu) { img = ImageKit.downsample(d, maxPixel: 700) }
                if img == nil, let art { img = ImageKit.downsample(art, maxPixel: 700) }
                if let d = img?.jpegData(compressionQuality: 0.8) { try? d.write(to: u, options: .atomic) } else { try? fm.removeItem(at: u) }
            }
            if let u = NextFilmStore.logo(g), before?.logoPath != film.logoPath || (film.logoPath != nil && !fm.fileExists(atPath: u.path)) {
                artChanged = true
                var img: UIImage?
                if let lu = logoURL, let (d, _) = try? await URLSession.shared.data(from: lu) { img = ImageKit.downsample(d, maxPixel: 500) }
                if let d = img?.pngData() { try? d.write(to: u, options: .atomic) } else { try? fm.removeItem(at: u) }
            }
        }
        // Pictures for films no longer on the list.
        let keep = Set(films.map(\.group))
        if let dir = NextFilmStore.folder, let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension != "json" {
                let g = String(f.lastPathComponent.prefix(36))
                if !keep.contains(g) { try? fm.removeItem(at: f) }
            }
        }
        guard films != saved || artChanged else { return }
        NextFilmStore.write(films)
        WidgetCenter.shared.reloadTimelines(ofKind: NextFilmStore.kind)
    }
}

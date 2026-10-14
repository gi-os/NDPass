import Foundation

/// The next few films, for the Home Screen widget. The widget can't open the ticket database
/// or download anything, so the app writes this list (and each film's poster and logo) to the
/// App Group and the widget reads it from there.
struct NextFilm: Codable, Hashable {
    var group: String          // Pass.group, for the link back into the app
    var title: String
    var venue: String
    var start: Date
    /// When the widget moves on to the film after this one (start plus runtime, or plus
    /// three hours when the runtime isn't known).
    var ends: Date
    var time: String           // "7:30 PM", as printed
    var seats: [String]        // one per ticket that has a seat
    var tickets: Int
    var runtime: Int?          // minutes
    var posterPath: String?    // TMDb paths, so unchanged art isn't downloaded again
    var logoPath: String?
}

extension NextFilm {
    /// "TONIGHT", "TOMORROW", "FRI".
    func dayWord(now: Date = Date()) -> String {
        let cal = Calendar.current
        if cal.isDate(start, inSameDayAs: now) { return cal.component(.hour, from: start) >= 17 ? "TONIGHT" : "TODAY" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(start, inSameDayAs: t) { return "TOMORROW" }
        if start.timeIntervalSince(now) < 6 * 86400 { return start.formatted(.dateTime.weekday(.wide)).uppercased() }
        return start.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    /// "TONIGHT · METROGRAPH".
    func eyebrow(now: Date = Date()) -> String {
        venue.isEmpty ? dayWord(now: now) : "\(dayWord(now: now)) · \(venue.uppercased())"
    }

    /// "1h 52m", nil without a runtime.
    var runtimeLabel: String? {
        guard let r = runtime, r > 0 else { return nil }
        return r >= 60 ? "\(r / 60)h \(r % 60)m" : "\(r)m"
    }
}

enum NextFilmStore {
    static let kind = "NextFilm"

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass")?
            .appendingPathComponent("Widget", isDirectory: true)
    }
    static var list: URL? { folder?.appendingPathComponent("films.json") }
    static func poster(_ g: String) -> URL? { folder?.appendingPathComponent("\(g)-poster.jpg") }
    static func logo(_ g: String) -> URL? { folder?.appendingPathComponent("\(g)-logo.png") }

    static func read() -> [NextFilm] {
        guard let u = list, let d = try? Data(contentsOf: u) else { return [] }
        return (try? JSONDecoder().decode([NextFilm].self, from: d)) ?? []
    }

    static func write(_ films: [NextFilm]) {
        guard let dir = folder, let u = list else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(films).write(to: u, options: .atomic)
    }
}

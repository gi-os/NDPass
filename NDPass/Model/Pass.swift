import Foundation
import SwiftData

enum EventKind: String, Codable, CaseIterable {
    case movie, sports, concert, theater, event, transit

    /// "Film", "Game", "Concert", "Show", "Event", "Trip".
    var name: String { ["Film", "Game", "Concert", "Show", "Event", "Trip"][Self.allCases.firstIndex(of: self)!] }
    var plural: String { ["Films", "Games", "Concerts", "Shows", "Events", "Trips"][Self.allCases.firstIndex(of: self)!] }
    var symbol: String { ["film", "sportscourt", "music.mic", "theatermasks", "ticket", "tram.fill"][Self.allCases.firstIndex(of: self)!] }

    /// The reader's word for it ("sports", "Broadway musical", "boarding pass") → a kind.
    static func parse(_ raw: String) -> EventKind {
        let s = raw.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { s.contains($0) } }
        if has(["transit", "train", "rail", "flight", "plane", "airline", "boarding", "bus", "ferry", "subway"]) { return .transit }
        if has(["sport", "game", "match"]) { return .sports }
        if has(["theat", "play", "musical", "broadway", "opera", "ballet", "dance", "comedy"]) { return .theater }
        if has(["concert", "music", "gig"]) { return .concert }
        if has(["movie", "film", "cinema", "screening"]) { return .movie }
        if has(["show"]) { return .theater }
        if has(["event", "museum", "exhibit", "festival", "tour", "conference", "attraction", "other"]) { return .event }
        return .movie
    }
}

enum TransitMode: String, Codable, CaseIterable {
    case train, flight, bus, ferry, other
    var name: String { ["Train", "Flight", "Bus", "Ferry", "Transit"][Self.allCases.firstIndex(of: self)!] }
    var symbol: String { ["tram.fill", "airplane", "bus.fill", "ferry.fill", "ticket"][Self.allCases.firstIndex(of: self)!] }
    /// What the number on the ticket is called: "Train 2151", "Flight UA 123".
    var tripLabel: String { ["Train", "Flight", "Bus", "Sailing", "Trip"][Self.allCases.firstIndex(of: self)!] }
    var gateLabel: String { self == .flight ? "Gate" : self == .train ? "Track" : self == .ferry ? "Pier" : "Gate" }

    static func parse(_ raw: String) -> TransitMode {
        let s = raw.lowercased()
        // Railways by name first: "Newark Airport" is also a train station.
        if ["amtrak", "lirr", "nj transit", "metro-north", "eurostar", "sncf", "trenitalia", "via rail"].contains(where: { s.contains($0) }) { return .train }
        if ["flight", "plane", "airline", "airport", "airways", "boarding pass"].contains(where: { s.contains($0) }) { return .flight }
        if ["train", "rail", "subway", "metro"].contains(where: { s.contains($0) }) { return .train }
        if ["bus", "coach", "greyhound", "megabus", "flixbus"].contains(where: { s.contains($0) }) { return .bus }
        if ["ferry", "boat", "sailing"].contains(where: { s.contains($0) }) { return .ferry }
        return .other
    }
}

/// One ticket. Several tickets for the same showing share a `group`, and the list shows the
/// group as one card.
@Model
final class Pass {
    var id: UUID = UUID()
    var group: UUID = UUID()
    var kindRaw: String = EventKind.movie.rawValue
    var title: String = ""
    var venue: String = ""
    var date: String = ""       // yyyy-MM-dd
    var time: String = ""       // h:mm AM
    var seat: String = ""
    var price: String = ""
    var bookingCode: String = ""
    var confidence: Double = 0
    @Attribute(.externalStorage) var photo: Data?
    @Attribute(.externalStorage) var crop: Data?
    @Attribute(.externalStorage) var art: Data?
    var tmdbID: Int?
    var posterPath: String?
    var backdropPath: String?
    var logoPath: String?
    var overview: String?
    var runtime: Int?
    var scannedCode: String?
    var scannedFormatRaw: String?
    var sourceURL: String?
    var sellerRaw: String?
    var createdAt: Date = Date()
    // Transit only. `venue` is where you board; `time` is departure.
    var transitModeRaw: String = ""
    var carrier: String = ""        // "Amtrak", "United"
    var trip: String = ""           // "2151", "UA 123"
    var destination: String = ""
    var arrival: String = ""        // h:mm AM
    var gate: String = ""           // track / gate / platform

    init(title: String = "") { self.title = title }

    /// A detached copy with every field, for moving between stores.
    func copy() -> Pass {
        let p = Pass(title: title)
        p.id = id; p.group = group; p.kindRaw = kindRaw; p.venue = venue; p.date = date; p.time = time
        p.seat = seat; p.price = price; p.bookingCode = bookingCode; p.confidence = confidence
        p.photo = photo; p.crop = crop; p.art = art
        p.tmdbID = tmdbID; p.posterPath = posterPath; p.backdropPath = backdropPath; p.logoPath = logoPath
        p.overview = overview; p.runtime = runtime; p.scannedCode = scannedCode; p.scannedFormatRaw = scannedFormatRaw
        p.sourceURL = sourceURL; p.sellerRaw = sellerRaw; p.createdAt = createdAt
        p.transitModeRaw = transitModeRaw; p.carrier = carrier; p.trip = trip
        p.destination = destination; p.arrival = arrival; p.gate = gate
        return p
    }

    var kind: EventKind {
        get { EventKind(rawValue: kindRaw) ?? .movie }
        set { kindRaw = newValue.rawValue }
    }

    var scannedFormat: Symbology? {
        get { scannedFormatRaw.flatMap(Symbology.init(rawValue:)) }
        set { scannedFormatRaw = newValue?.rawValue }
    }

    var transitMode: TransitMode {
        get { TransitMode(rawValue: transitModeRaw) ?? .other }
        set { transitModeRaw = newValue.rawValue }
    }

    /// "TRAIN · AMTRAK 2151", "FILM", for eyebrows.
    var kindLine: String {
        guard kind == .transit else { return kind.name.uppercased() }
        let num = [carrier, trip].filter { !$0.isEmpty }.joined(separator: " ")
        return ([transitMode.name] + (num.isEmpty ? [] : [num])).joined(separator: " · ").uppercased()
    }

    var seller: Seller? {
        get { sellerRaw.flatMap(Seller.init(rawValue:)) }
        set { sellerRaw = newValue?.rawValue }
    }

    var start: Date? { PassTimes.start(date: date, time: time) }
    /// A trip's arrival, the next day if it's earlier than departure (overnight trains, red-eyes).
    var arrivalDate: Date? {
        guard kind == .transit, let s = start, let a = PassTimes.start(date: date, time: arrival) else { return nil }
        // The next calendar day (not +24 h, which is an hour off across a clock change).
        return a < s ? (Calendar.current.date(byAdding: .day, value: 1, to: a) ?? a.addingTimeInterval(86400)) : a
    }
    var isArchived: Bool {
        // No date yet (a TBD game, an undated stub): upcoming for four months after it was
        // added, then it moves to the past so it doesn't sit in Up Next forever.
        if PassTimes.day(date) == nil { return Date().timeIntervalSince(createdAt) > 120 * 86400 }
        if let a = arrivalDate { return Date() > a }
        return PassTimes.isArchived(date: date, time: time, runtime: runtime)
    }
    /// Dated showings in order; a TBD date sorts after every dated one.
    var sortDate: Date { start ?? PassTimes.day(date) ?? Date.distantFuture.addingTimeInterval(-createdAt.timeIntervalSince1970) }
    /// For lists: upcoming by showtime (TBD last); past ones by when they were, and undated
    /// past stubs by when they were added (not at the top of the past list).
    var listDate: Date { isArchived ? (start ?? PassTimes.day(date) ?? createdAt) : sortDate }
    var dateTBD: Bool { PassTimes.day(date) == nil }
    var timeTBD: Bool { PassTimes.start(date: "2000-01-01", time: time) == nil }
    /// "Aug 6" / "Date TBD", "7:30 PM" / "TBD", for labels.
    var dateLabel: String { PassTimes.humanDate(date) ?? "Date TBD" }
    var timeLabel: String { timeTBD ? "TBD" : time }
    var posterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
    var bigPosterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w780\($0)") } }
    var logoURL: URL? { logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
    var backdropURL: URL? { backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") } }

    /// Same kind, title, venue, date and time: the same showing.
    func sameShowing(as other: Pass) -> Bool {
        kind == other.kind && title.lowercased() == other.title.lowercased() && date == other.date && time == other.time
            && venue.lowercased() == other.venue.lowercased() && trip.lowercased() == other.trip.lowercased()
    }
}

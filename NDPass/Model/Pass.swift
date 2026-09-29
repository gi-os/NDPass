import Foundation
import SwiftData

enum EventKind: String, Codable, CaseIterable { case movie, sports, concert }

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

    var seller: Seller? {
        get { sellerRaw.flatMap(Seller.init(rawValue:)) }
        set { sellerRaw = newValue?.rawValue }
    }

    var start: Date? { PassTimes.start(date: date, time: time) }
    var isArchived: Bool { PassTimes.isArchived(date: date, time: time, runtime: runtime) }
    var sortDate: Date { start ?? PassTimes.day(date) ?? createdAt }
    var posterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
    var bigPosterURL: URL? { posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w780\($0)") } }
    var logoURL: URL? { logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
    var backdropURL: URL? { backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") } }

    /// Same kind, title, venue, date and time: the same showing.
    func sameShowing(as other: Pass) -> Bool {
        kind == other.kind && title.lowercased() == other.title.lowercased() && date == other.date && time == other.time
            && venue.lowercased() == other.venue.lowercased()
    }
}

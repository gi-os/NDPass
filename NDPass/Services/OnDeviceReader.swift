import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reads a ticket without anything leaving the phone.
///
/// 1. Vision finds the paper (document segmentation) and reads its text.
/// 2. On iOS 26 with Apple Intelligence, Apple's on-device model turns that text into the
///    ticket's fields. Without it, patterns pull out what they can: times, dates, prices,
///    seats, a code, and the most title-like line.
/// Dates and times go through the same rules as Claude's answers (TicketDate, PassTimes).
enum OnDeviceReader {
    enum Engine { case appleIntelligence, patterns }

    static var engine: Engine {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable { return .appleIntelligence }
        #endif
        return .patterns
    }

    static func read(_ image: UIImage, extraText: String? = nil) async -> Parsed {
        guard let cg = image.cgImage else { return Parsed() }
        let box = paper(cg)
        var lines = text(cg, in: box)
        if let extra = extraText { lines += extra.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        var p = await read(lines: lines)
        p.box = box
        return p
    }

    /// Fields from lines of text (OCR, an email, a page).
    static func read(lines: [String]) async -> Parsed {
        var p = Parsed()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable, let q = await model(lines) { p = q }
        else { p = patterns(lines) }
        #else
        p = patterns(lines)
        #endif
        p.rawText = lines.prefix(200).joined(separator: "\n")
        // A year only counts if it's in the ticket's own text (the model can make one up).
        p.date = TicketDate.resolveFromModel(p.date, evidence: p.rawText) ?? ""
        p.time = PassTimes.normalizeTime(p.time, literal: p.kind == .transit) ?? ""
        if p.kind == .transit && p.mode.isEmpty { p.mode = TransitMode.parse(p.rawText).rawValue }
        p.venue = PassTimes.display(p.venue)
        p.code = BookingCode.normalize(p.code) ?? ""
        if p.title.isEmpty { p.title = "Untitled" }
        p.confidence = 0   // only Claude reports a real confidence
        return p
    }

    /// The ticket's outline, normalized with a top-left origin, if Vision finds one.
    static func paper(_ cg: CGImage) -> CGRect? {
        let req = VNDetectDocumentSegmentationRequest()
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        guard let obs = req.results?.first, obs.confidence > 0.5 else { return nil }
        let r = obs.boundingBox
        return CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height)
    }

    /// Recognized lines, top to bottom.
    static func text(_ cg: CGImage, in box: CGRect?) -> [String] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        if let b = box { req.regionOfInterest = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height) }
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        let obs = (req.results ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        return obs.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct Fields {
        @Guide(description: "What the ticket is for: movie, sports, concert, theater (plays, musicals, comedy), event (museum, festival, anything else) or transit (train, flight, bus, ferry, boarding pass)")
        var kind: String
        @Guide(description: "For a film, its title. For a game, only the two teams as 'Team 1 vs Team 2', like 'Knicks vs Celtics'. For a concert, only the band or artist name, no tour name. For a show or event, its name. For transit, the route as 'From → To'")
        var title: String
        @Guide(description: "The cinema, stadium, arena or venue name. For transit, the station or airport you board at")
        var venue: String
        @Guide(description: "The date as YYYY-MM-DD if a year is printed, otherwise MM-DD. Empty if there is no date")
        var date: String
        @Guide(description: "The start time as h:mm AM/PM. Empty if there is none")
        var time: String
        @Guide(description: "Seat, row or section, or empty")
        var seat: String
        @Guide(description: "The price with its currency symbol, or empty")
        var price: String
        @Guide(description: "The booking or confirmation reference exactly as printed, or empty. Never a seat or a price")
        var code: String
        @Guide(description: "True if the text is not from an event ticket at all")
        var notATicket: Bool
        @Guide(description: "Transit only: train, flight, bus or ferry. Empty otherwise")
        var mode: String
        @Guide(description: "Transit only: the railway, airline or bus line, like Amtrak or United. Empty otherwise")
        var carrier: String
        @Guide(description: "Transit only: the train, flight or bus number, like 2151 or UA 123. Empty otherwise")
        var trip: String
        @Guide(description: "Transit only: where it arrives, station or airport. Empty otherwise")
        var destination: String
        @Guide(description: "Transit only: the arrival time as h:mm AM/PM. Empty otherwise")
        var arrival: String
        @Guide(description: "Transit only: track, platform or gate. Empty otherwise")
        var gate: String
    }

    @available(iOS 26.0, *)
    static func model(_ lines: [String]) async -> Parsed? {
        guard !lines.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: """
        You read text recognized from a photo or screenshot of an event ticket and fill in its fields. \
        Use only what the text says. A date with no year printed is returned as MM-DD. \
        Showings are almost always 11 AM to midnight, so a 1-6 AM time is a misread PM, \
        except for trains, flights and buses, whose times are copied exactly.
        """)
        do {
            let r = try await session.respond(to: "Ticket text:\n" + lines.joined(separator: "\n"), generating: Fields.self)
            let f = r.content
            var p = Parsed()
            p.notATicket = f.notATicket
            p.kind = EventKind.parse(f.kind)
            p.title = f.title; p.venue = f.venue; p.date = f.date; p.time = f.time
            p.seat = f.seat; p.price = f.price; p.code = f.code
            if p.kind == .transit {
                p.mode = f.mode; p.carrier = f.carrier; p.trip = f.trip; p.gate = f.gate
                p.destination = Transit.place(f.destination)
                p.arrival = PassTimes.normalizeTime(f.arrival, literal: true) ?? ""
            }
            return p
        } catch {
            return nil
        }
    }
    #endif

    // MARK: patterns, for phones without Apple Intelligence

    static func patterns(_ lines: [String]) -> Parsed {
        var p = Parsed()
        let all = lines.joined(separator: "\n")
        func first(_ re: Regex<AnyRegexOutput>, in s: String) -> String? {
            guard let m = try? re.firstMatch(in: s) else { return nil }
            return String(s[m.range])
        }
        if let r = try? Regex("(?i)\\b\\d{1,2}:\\d{2}\\s*[ap]\\.?m\\.?"), let t = first(r, in: all) { p.time = t }
        else if let r = try? Regex("\\b([01]?\\d|2[0-3]):[0-5]\\d\\b"), let t = first(r, in: all) { p.time = t }
        if let r = try? Regex("[$€£]\\s?\\d+[.,]\\d{2}"), let t = first(r, in: all) { p.price = t }
        p.date = date(in: all) ?? ""
        if let line = lines.first(where: { $0.range(of: "(?i)\\b(seat|row|sec(tion)?)\\b", options: .regularExpression) != nil }) { p.seat = line }
        // The reference after its label (on the same line or the next): letters and digits
        // with at least one digit, so the label itself ("ORDER", "BOOKING") or a row of dashes
        // is never taken for it.
        if let r = try? Regex("\\b(?=[A-Z0-9-]*[0-9])[A-Z0-9][A-Z0-9-]{4,}\\b") {
            let label = "(?i)\\b(booking|confirmation|ref(erence)?|order)\\b"
            outer: for (i, line) in lines.enumerated() where line.range(of: label, options: .regularExpression) != nil {
                let after = line.range(of: "(?i)(booking|confirmation|ref(erence)?|order)[^A-Za-z0-9]*(no\\.?|number|#|code)?", options: .regularExpression).map { String(line[$0.upperBound...]) } ?? line
                for candidate in [after, line, i + 1 < lines.count ? lines[i + 1] : ""] {
                    if let c = first(r, in: candidate) { p.code = c; break outer }
                }
            }
        }
        let venues = ["cinema", "theater", "theatre", "amc", "regal", "alamo", "arena", "stadium", "garden", "hall", "center", "centre", "film forum", "metrograph", "angelika", "ifc", "station", "terminal", "airport"]
        if let v = lines.first(where: { l in venues.contains { l.lowercased().contains($0) } }) { p.venue = v }
        // The title: the longest line that isn't one of the above and isn't mostly digits.
        let taken = Set([p.venue, p.seat].filter { !$0.isEmpty })
        p.title = lines.filter { l in
            !taken.contains(l) && l.count >= 3 && l.filter(\.isLetter).count * 2 > l.count
                && l.range(of: "(?i)(admit|ticket|seat|row|price|total|tax|date|time|screen|auditorium)", options: .regularExpression) == nil
        }.max { $0.count < $1.count } ?? ""
        // "Knicks vs Celtics", "Knicks @ Celtics" (an @ with spaces round it: not an email).
        if all.range(of: "(?i)(\\bvs\\.?\\s|\\sv\\.\\s|\\s@\\s)", options: .regularExpression) != nil { p.kind = .sports }
        if all.range(of: "(?i)\\b(boarding pass|departs?|departure|platform|flight no|flight|amtrak|nj transit|lirr|metro-north|greyhound|megabus|flixbus|eurostar|ferry|coach \\d)\\b", options: .regularExpression) != nil {
            p.kind = .transit
            p.mode = TransitMode.parse(all).rawValue
        } else if all.range(of: "(?i)\\b(broadway|musical|playbill|orchestra|mezzanine|balcony|comedy|opera|ballet)\\b", options: .regularExpression) != nil, p.kind == .movie {
            p.kind = .theater
        } else if all.range(of: "(?i)\\b(museum|exhibition|exhibit|festival|general admission|timed entry)\\b", options: .regularExpression) != nil, p.kind == .movie {
            p.kind = .event
        }
        return p
    }

    /// "DEC 18", "12/18/2026", "2026-12-18", "Friday, October 9" → a date string TicketDate understands.
    static func date(in s: String) -> String? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if let r = try? Regex("\\b((?:19|20)[0-9]{2})-([0-9]{1,2})-([0-9]{1,2})\\b"), let m = try? r.firstMatch(in: s) { return String(s[m.range]) }
        if let r = try? Regex("\\b(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?\\b"), let m = try? r.firstMatch(in: s) {
            let parts = String(s[m.range]).split(separator: "/").map(String.init)
            if parts.count >= 2, let mo = Int(parts[0]), let d = Int(parts[1]), (1...12).contains(mo), (1...31).contains(d) {
                if parts.count == 3, var y = Int(parts[2]) {
                    if y < 100 { y += (y > (Calendar(identifier: .gregorian).component(.year, from: Date()) % 100) + 1) ? 1900 : 2000 }
                    return String(format: "%04d-%02d-%02d", y, mo, d)
                }
                return String(format: "%02d-%02d", mo, d)
            }
        }
        // Month names as written ("Dec", "December", "Sept."), not words that start like one
        // ("Marvel 2", "Junction 3").
        if let r = try? Regex("(?i)\\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\\.?\\s+([0-9]{1,2})(?:st|nd|rd|th)?\\b(?:,?\\s+(20[0-9]{2}|19[0-9]{2}))?"),
           let m = try? r.firstMatch(in: s) {
            let text = String(s[m.range]).lowercased()
            guard let mi = months.firstIndex(where: { text.hasPrefix($0) }) else { return nil }
            let nums = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard let d = nums.first, (1...31).contains(d) else { return nil }
            if nums.count > 1, nums[1] > 1900 { return String(format: "%04d-%02d-%02d", nums[1], mi + 1, d) }
            return String(format: "%02d-%02d", mi + 1, d)
        }
        return nil
    }
}

/// Which reader NDPass uses. On-device unless you turn Claude on and have a key.
enum ReaderChoice: String, CaseIterable {
    case onDevice, claude
    var title: String { self == .onDevice ? "On this iPhone" : "Claude (your API key)" }
    static var current: ReaderChoice {
        get { Store.defaults.string(forKey: "reader").flatMap(ReaderChoice.init(rawValue:)) ?? .onDevice }
        set { Store.defaults.set(newValue.rawValue, forKey: "reader") }
    }
}

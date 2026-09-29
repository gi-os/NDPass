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
        p.date = TicketDate.resolveFromModel(p.date) ?? ""
        p.time = PassTimes.normalizeTime(p.time) ?? ""
        p.venue = PassTimes.titleCase(p.venue) ?? ""
        p.code = BookingCode.normalize(p.code) ?? ""
        if p.title.isEmpty { p.title = "Untitled" }
        p.confidence = lines.isEmpty ? 0 : (engine == .appleIntelligence ? 0.8 : 0.5)
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
        @Guide(description: "What the ticket is for: movie, sports or concert")
        var kind: String
        @Guide(description: "The film title, the matchup like 'Knicks vs Celtics', or the artist or tour name, exactly as printed")
        var title: String
        @Guide(description: "The cinema, stadium, arena or venue name")
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
    }

    @available(iOS 26.0, *)
    static func model(_ lines: [String]) async -> Parsed? {
        guard !lines.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: """
        You read text recognized from a photo or screenshot of an event ticket and fill in its fields. \
        Use only what the text says. A date with no year printed is returned as MM-DD. \
        Showings are almost always 11 AM to midnight, so a 1-6 AM time is a misread PM.
        """)
        do {
            let r = try await session.respond(to: "Ticket text:\n" + lines.joined(separator: "\n"), generating: Fields.self)
            let f = r.content
            var p = Parsed()
            p.notATicket = f.notATicket
            switch f.kind.lowercased() { case let k where k.contains("sport"): p.kind = .sports; case let k where k.contains("concert"): p.kind = .concert; default: p.kind = .movie }
            p.title = f.title; p.venue = f.venue; p.date = f.date; p.time = f.time
            p.seat = f.seat; p.price = f.price; p.code = f.code
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
        if let line = lines.first(where: { $0.range(of: "(?i)\\b(booking|confirmation|ref(erence)?|order)\\b", options: .regularExpression) != nil }),
           let r = try? Regex("[A-Z0-9-]{5,}"), let c = first(r, in: line) { p.code = c }
        let venues = ["cinema", "theater", "theatre", "amc", "regal", "alamo", "arena", "stadium", "garden", "hall", "center", "centre", "film forum", "metrograph", "angelika", "ifc"]
        if let v = lines.first(where: { l in venues.contains { l.lowercased().contains($0) } }) { p.venue = v }
        // The title: the longest line that isn't one of the above and isn't mostly digits.
        let taken = Set([p.venue, p.seat].filter { !$0.isEmpty })
        p.title = lines.filter { l in
            !taken.contains(l) && l.count >= 3 && l.filter(\.isLetter).count * 2 > l.count
                && l.range(of: "(?i)(admit|ticket|seat|row|price|total|tax|date|time|screen|auditorium)", options: .regularExpression) == nil
        }.max { $0.count < $1.count } ?? ""
        if all.range(of: "(?i)\\b(vs\\.?|v\\.|@)\\b", options: .regularExpression) != nil { p.kind = .sports }
        return p
    }

    /// "DEC 18", "12/18/2026", "2026-12-18", "Friday, October 9" → a date string TicketDate understands.
    static func date(in s: String) -> String? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if let r = try? Regex("\\b(20\\d{2})-(\\d{1,2})-(\\d{1,2})\\b"), let m = try? r.firstMatch(in: s) { return String(s[m.range]) }
        if let r = try? Regex("\\b(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?\\b"), let m = try? r.firstMatch(in: s) {
            let parts = String(s[m.range]).split(separator: "/").map(String.init)
            if parts.count >= 2, let mo = Int(parts[0]), let d = Int(parts[1]), (1...12).contains(mo), (1...31).contains(d) {
                if parts.count == 3, var y = Int(parts[2]) { if y < 100 { y += 2000 }; return String(format: "%04d-%02d-%02d", y, mo, d) }
                return String(format: "%02d-%02d", mo, d)
            }
        }
        if let r = try? Regex("(?i)\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(20\\d{2}))?"),
           let m = try? r.firstMatch(in: s) {
            let text = String(s[m.range]).lowercased()
            guard let mi = months.firstIndex(where: { text.hasPrefix($0) }) else { return nil }
            let nums = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard let d = nums.first, (1...31).contains(d) else { return nil }
            if nums.count > 1, nums[1] > 2000 { return String(format: "%04d-%02d-%02d", nums[1], mi + 1, d) }
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
        get { UserDefaults.standard.string(forKey: "reader").flatMap(ReaderChoice.init(rawValue:)) ?? .onDevice }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "reader") }
    }
}

import UIKit

struct Parsed {
    var kind: EventKind = .movie
    var title = "Untitled"
    var venue = ""
    var date = ""
    var time = ""
    var seat = ""
    var price = ""
    var code = ""
    var confidence = 0.0
    var box: CGRect?   // normalized 0...1, top-left origin
    var notATicket = false
    var seller: Seller?
    var rawText = ""
}

enum ParseError: LocalizedError {
    case noKey, http(Int, String), unreadable
    var errorDescription: String? {
        switch self {
        case .noKey: return "Add your Anthropic key in Settings to read tickets automatically."
        case .http(let c, let m): return "Claude answered \(c): \(m)"
        case .unreadable: return "Couldn't read an answer from Claude."
        }
    }
}

/// Claude Haiku reads the stub. Same prompt as BrightPasses, including "leave the year off
/// when the paper does" and the tight 0-1000 box around the paper.
enum Parser {
    static let model = "claude-haiku-4-5-20251001"

    static func prompt(today: Date) -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        return """
        Analyze this image of an event ticket (movie, sports game, or concert) and extract
        the following. Return ONLY valid JSON, no markdown, no backticks, no explanation.
        {
          "kind": "movie" | "sports" | "concert",
          "movieTitle": "exact event title on ticket (film title, matchup like 'Knicks vs Celtics', or artist/tour name)",
          "theater": "theater/cinema, stadium/arena, or venue name",
          "date": "YYYY-MM-DD if a year is printed on the ticket, otherwise MM-DD",
          "time": "h:mm AM/PM",
          "seat": "seat/row info or null",
          "price": "price with $ or null",
          "code": "booking/confirmation reference, exactly as printed, or null",
          "seller": "who sold it if shown (ticketmaster, livenation, dice, axs, seatgeek, eventbrite, stubhub, fandango, amc, regal, atom, alamo, eventim, universe) or null",
          "confidence": 0.95,
          "box": [x0, y0, x1, y1]
        }
        "box" is the TIGHT rectangle around ONLY the printed ticket/receipt paper,
        as INTEGERS on a 0-1000 grid: [x0,y0] = top-left corner, [x1,y1] = bottom-right,
        where 0,0 is the image's top-left and 1000,1000 is bottom-right.
        Exclude any hand, table, background, or empty margins outside the ticket.
        Trace the actual paper edges. Only use [0,0,1000,1000] if the paper truly
        bleeds to every edge of the photo.
        The image may instead be a screenshot of a web page, an e-mail, or an app showing
        a ticket or an order. Then read the event from the screen and make "box" the part
        of the screen that shows the ticket itself, leaving out menus and page chrome.
        Today is \(df.string(from: today)). A ticket with no year printed on it is for an UPCOMING showing,
        so do not guess the year: return MM-DD and let the app work it out. Return a
        four-digit year only when you can actually read one on the paper.
        "code" is the booking or confirmation reference: the human-readable string printed
        under or beside the barcode, copied character for character. Never invent one and
        never substitute a seat number or an order total — return null if none is legible.
        Rules: time is 12-hour with AM/PM.
        Read AM/PM carefully from the ticket. Showings and events are almost always
        matinee or evening (11:00 AM - 11:59 PM); a 1-6 AM start time is almost
        certainly a misread PM. confidence 0-1 over all fields.
        "kind" is your best read of what the ticket admits you to: "movie" for a film
        screening, "sports" for a game or match, "concert" for live music or a show.
        If the image is NOT a ticket at all, return {"error":"not_a_ticket","confidence":0}.
        """
    }

    /// Longest edge 1568 px, which is what the vision model works at anyway.
    static func jpegForModel(_ image: UIImage) -> Data? {
        let maxEdge: CGFloat = 1568
        let s = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * s).rounded(), height: (image.size.height * s).rounded())
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).jpegData(withCompressionQuality: 0.85) { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func parse(_ image: UIImage, key: String?) async throws -> Parsed {
        guard let key else { throw ParseError.noKey }
        guard let jpeg = jpegForModel(image) else { throw ParseError.unreadable }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "messages": [["role": "user", "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                ["type": "text", "text": prompt(today: Date())]
            ]]]
        ]
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = ParseError.unreadable
        for attempt in 0..<3 {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200 else {
                    let msg = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]).flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? ""
                    throw ParseError.http(code, msg)
                }
                return try decode(data)
            } catch let e as ParseError {
                if case .http(let c, _) = e, c < 500 && c != 429 { throw e }
                lastError = e
            } catch { lastError = error }
            try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 800_000_000)
        }
        throw lastError
    }

    static func decode(_ data: Data) throws -> Parsed {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String else { throw ParseError.unreadable }
        return try decodeText(text)
    }

    static func decodeText(_ text: String) throws -> Parsed {
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"), a < b,
              let j = try JSONSerialization.jsonObject(with: Data(text[a...b].utf8)) as? [String: Any] else { throw ParseError.unreadable }
        var p = Parsed()
        if j["error"] as? String == "not_a_ticket" { p.notATicket = true; return p }
        func str(_ k: String) -> String {
            guard let v = j[k], !(v is NSNull) else { return "" }
            let s = "\(v)".trimmingCharacters(in: .whitespacesAndNewlines)
            return s.lowercased() == "null" ? "" : s
        }
        p.title = str("movieTitle").isEmpty ? "Untitled" : str("movieTitle")
        p.venue = PassTimes.titleCase(str("theater")) ?? ""
        p.date = TicketDate.resolveFromModel(str("date")) ?? ""
        p.time = PassTimes.normalizeTime(str("time")) ?? ""
        p.seat = str("seat")
        p.price = str("price")
        p.code = BookingCode.normalize(str("code")) ?? ""
        p.confidence = (j["confidence"] as? NSNumber)?.doubleValue ?? 0
        p.seller = Seller(rawValue: str("seller").lowercased().replacingOccurrences(of: " ", with: ""))
        switch str("kind").lowercased() { case "sports": p.kind = .sports; case "concert": p.kind = .concert; default: p.kind = .movie }
        if let box = j["box"] as? [Any], box.count == 4 {
            let v = box.compactMap { ($0 as? NSNumber)?.doubleValue }
            if v.count == 4, v[2] > v[0], v[3] > v[1] {
                p.box = CGRect(x: v[0] / 1000, y: v[1] / 1000, width: (v[2] - v[0]) / 1000, height: (v[3] - v[1]) / 1000)
            }
        }
        return p
    }
}

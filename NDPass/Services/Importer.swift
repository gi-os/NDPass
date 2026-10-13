import UIKit
import SwiftData

/// Photo → Claude → crop → the ticket's own code → poster → saved, one at a time, off the
/// main thread. Every step is logged so a failed scan says where it stopped.
@MainActor
final class Importer: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var log: [String] = []
    @Published var lastError: String?

    func add(_ image: UIImage, sourceURL: String? = nil, prefetchedText: String? = nil, into ctx: ModelContext) async -> Pass? {
        guard let p = await make(image, sourceURL: sourceURL, prefetchedText: prefetchedText) else { return nil }
        file(p, into: ctx)
        return p
    }

    /// Read a ticket into a Pass that isn't saved yet (the share sheet shows it first).
    func make(_ image: UIImage, sourceURL: String? = nil, prefetchedText: String? = nil) async -> Pass? {
        busy = true
        log = []
        lastError = nil
        defer { busy = false }
        let upright = ImageKit.fit(image)
        var parsed = Parsed()
        if ReaderChoice.current == .claude && AIConsent.granted && Keys.get(.anthropic) != nil {
            step("Reading the ticket with Claude…")
            do {
                parsed = try await Parser.parse(upright, key: Keys.get(.anthropic))
            } catch {
                step("Claude couldn't read it (\(error.localizedDescription)). Reading on this iPhone instead…")
                parsed = await OnDeviceReader.read(upright)
            }
        } else {
            step(OnDeviceReader.engine == .appleIntelligence ? "Reading the ticket on this iPhone…" : "Reading the ticket's text on this iPhone…")
            parsed = await OnDeviceReader.read(upright, extraText: prefetchedText)
        }
        if parsed.notATicket { lastError = "That doesn't look like a ticket."; step("Not a ticket."); return nil }
        step("\(parsed.title) · \(PassTimes.humanDate(parsed.date) ?? "no date") · \(parsed.time)")

        let crop = parsed.box.flatMap { Self.crop(upright, to: $0) }
        if parsed.seller == nil { parsed.seller = Seller.detect(text: parsed.rawText + " " + parsed.title + " " + parsed.venue, url: sourceURL) }
        let p = Self.pass(from: parsed)
        p.seat = parsed.seat
        p.price = parsed.price
        p.bookingCode = parsed.code
        p.confidence = parsed.confidence
        p.sourceURL = sourceURL
        p.seller = parsed.seller
        if let sl = parsed.seller { step("Sold by \(sl.name).") }
        p.photo = upright.jpegData(compressionQuality: 0.85)
        p.crop = crop?.jpegData(compressionQuality: 0.9)

        step("Looking for the ticket's own barcode…")
        let found = await Task.detached(priority: .userInitiated) { Barcodes.read(crop: crop, photo: upright) }.value
        if let found {
            p.scannedCode = found.text
            p.scannedFormat = found.format
            step("Found a \(found.format.rawValue.uppercased()) code.")
        } else { step("No readable code in the photo.") }
        // Nothing a ticket has (a name, a date, a reference or a code): a photo of something else.
        if (parsed.title == "Untitled" || parsed.title.isEmpty) && parsed.date.isEmpty && parsed.code.isEmpty && found == nil {
            lastError = "That doesn't look like a ticket."; step("No ticket found in the photo."); return nil
        }

        await decorate(p)
        return p
    }

    /// The fields every reader fills, onto a new Pass. Trips keep their station codes and
    /// their early-morning times as printed.
    static func pass(from parsed: Parsed) -> Pass {
        let transit = parsed.kind == .transit
        let title = EventTitle.clean(parsed.title, kind: parsed.kind)
        let p = Pass(title: transit ? title : PassTimes.display(title))
        p.kind = parsed.kind
        p.venue = transit ? Transit.place(parsed.venue) : PassTimes.display(parsed.venue)
        p.date = PassTimes.tbd(parsed.date) ? "" : parsed.date
        p.time = PassTimes.tbd(parsed.time) ? "" : (PassTimes.normalizeTime(parsed.time, literal: transit) ?? parsed.time)
        if transit {
            p.transitMode = TransitMode(rawValue: parsed.mode.lowercased()) ?? TransitMode.parse(parsed.mode + " " + parsed.carrier)
            p.carrier = PassTimes.display(parsed.carrier)
            p.trip = parsed.trip
            p.destination = parsed.destination
            p.arrival = PassTimes.normalizeTime(parsed.arrival, literal: true) ?? ""
            p.gate = parsed.gate
        }
        return p
    }

    /// Save a read ticket, next to any other ticket for the same showing.
    func file(_ p: Pass, into ctx: ModelContext) {
        let all = (try? ctx.fetch(FetchDescriptor<Pass>())) ?? []
        if let twin = all.first(where: { $0.sameShowing(as: p) }) { p.group = twin.group; step("Grouped with your other ticket.") }
        ctx.insert(p)
        try? ctx.save()
        Reminders.sync(all + [p])
        CalendarSync.sync(all + [p])
        step("Saved.")
    }

    /// A ticket from text: a shared email, a link's page, a PDF's words. Read on-device
    /// (or by Claude if that's on), with the image if there is one.
    func add(text: String, image: UIImage?, sourceURL: String?, into ctx: ModelContext) async -> Pass? {
        guard let p = await make(text: text, image: image, sourceURL: sourceURL) else { return nil }
        file(p, into: ctx)
        return p
    }

    func make(text: String, image: UIImage?, sourceURL: String?) async -> Pass? {
        if let image { return await make(image, sourceURL: sourceURL, prefetchedText: text) }
        busy = true; log = []; lastError = nil
        defer { busy = false }
        var body = text
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let s = sourceURL, let u = URL(string: s) {
            step("Opening the link…")
            body = await Self.pageText(u)
        }
        step("Reading the ticket on this iPhone…")
        func lines(_ t: String) -> [String] { t.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        var parsed = await OnDeviceReader.read(lines: lines(body))
        // Shared text with a link (an email's "view your tickets"): try the page too.
        if (parsed.notATicket || parsed.title == "Untitled" && parsed.date.isEmpty), !text.isEmpty, let s = sourceURL, let u = URL(string: s) {
            step("Opening the link…")
            let page = await Self.pageText(u)
            if !page.isEmpty { body = text + "\n" + page; parsed = await OnDeviceReader.read(lines: lines(body)) }
        }
        if parsed.notATicket || parsed.title == "Untitled" && parsed.date.isEmpty { lastError = "Couldn't find a ticket in that."; step("No ticket found."); return nil }
        parsed.seller = Seller.detect(text: body, url: sourceURL)
        let p = Self.pass(from: parsed)
        p.seat = parsed.seat; p.price = parsed.price; p.bookingCode = parsed.code; p.confidence = parsed.confidence
        p.sourceURL = sourceURL
        p.seller = parsed.seller
        step("\(parsed.title) · \(PassTimes.humanDate(parsed.date) ?? "no date")")
        await decorate(p)
        return p
    }

    /// A web page as lines of text (e-ticket pages are often mostly script; this is best effort).
    static func pageText(_ u: URL) async -> String {
        guard let (d, _) = try? await URLSession.shared.data(from: u), let html = String(data: d, encoding: .utf8) else { return "" }
        var s = html.replacingOccurrences(of: "(?s)<(script|style)[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ")
        return s
    }

    /// Poster and runtime for a film, drawn art for everything else.
    func decorate(_ p: Pass) async {
        if p.kind == .movie, let key = Keys.get(.tmdb) {
            step("Finding the poster…")
            // The exact title first: a repertory screening of an old film shouldn't get this
            // year's film of a similar name. Then the ticket's year, then anything.
            let year = String(p.date.prefix(4))
            let thisYear = await TMDb.search(p.title, year: year, key: key)
            let any = await TMDb.search(p.title, key: key)
            func same(_ m: MovieMatch) -> Bool { m.title.lowercased().filter(\.isLetter) == p.title.lowercased().filter(\.isLetter) }
            let m = thisYear.first(where: same) ?? any.first(where: same) ?? thisYear.first ?? any.first
            if let m, !p.isDeleted {
                apply(m, to: p)
                let runtime = await TMDb.runtime(m.id, key: key)
                guard !p.isDeleted else { return }
                p.runtime = runtime
                await TMDb.art(for: p, key: key)
            }
        } else if p.kind != .movie {
            switch p.kind {
            case .concert: step("Finding the artist…")
            case .sports: step("Finding the teams…")
            default: step("Drawing the \(p.kind.name.lowercased())'s art…")
            }
            await EventArt.decorate(p)
        }
    }

    func apply(_ m: MovieMatch, to p: Pass) {
        p.tmdbID = m.id
        p.posterPath = m.posterPath
        p.backdropPath = m.backdropPath
        p.overview = m.overview.isEmpty ? nil : m.overview
    }

    private func step(_ s: String) { log.append(s) }
    /// A line after a batch, kept on screen with the last ticket's steps.
    func note(_ s: String) { log.append(s) }

    /// The model's box, with a little margin, clamped to the photo.
    static func crop(_ img: UIImage, to box: CGRect) -> UIImage? {
        guard let cg = img.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        if box.width > 0.97 && box.height > 0.97 { return nil }
        var r = CGRect(x: box.minX * w, y: box.minY * h, width: box.width * w, height: box.height * h).insetBy(dx: -0.02 * w, dy: -0.02 * h)
        r = r.intersection(CGRect(x: 0, y: 0, width: w, height: h)).integral
        guard r.width > 40, r.height > 40, let out = cg.cropping(to: r) else { return nil }
        return UIImage(cgImage: out)
    }
}

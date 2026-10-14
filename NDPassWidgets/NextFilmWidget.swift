import SwiftUI
import WidgetKit
import UIKit

/// The next film on the Home Screen: the poster, the day, the time and the seats, cut like a
/// ticket stub. Reads the list the app keeps in the App Group (see FilmWidget).
struct NextFilmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NextFilmStore.kind, provider: NextFilmProvider()) { entry in
            NextFilmView(entry: entry)
        }
        .configurationDisplayName("Next Film")
        .description("Your next film: poster, showtime and seats.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct NextFilmEntry: TimelineEntry {
    let date: Date
    let film: NextFilm?
    /// How many more films after this one.
    let more: Int
}

struct NextFilmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextFilmEntry {
        NextFilmEntry(date: Date(), film: .sample, more: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextFilmEntry) -> Void) {
        let films = NextFilmStore.read().filter { $0.ends > Date() }
        completion(NextFilmEntry(date: Date(), film: films.first ?? (context.isPreview ? .sample : nil), more: max(films.count - 1, 0)))
    }

    /// One entry now, one at midnight (the day word changes) and one as each film ends, so the
    /// widget moves on to the next film by itself.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextFilmEntry>) -> Void) {
        let now = Date()
        let films = NextFilmStore.read().filter { $0.ends > now }.sorted { $0.start < $1.start }
        var dates: Set<Date> = [now]
        for f in films {
            dates.insert(f.ends)
            // "TOMORROW" becomes "TONIGHT" at midnight, and the time line becomes a countdown
            // in the last day.
            dates.insert(Calendar.current.startOfDay(for: f.start))
            dates.insert(f.start.addingTimeInterval(-86400))
            dates.insert(f.start)
        }
        let entries = dates.filter { $0 >= now }.sorted().map { d -> NextFilmEntry in
            let left = films.filter { $0.ends > d }
            return NextFilmEntry(date: d, film: left.first, more: max(left.count - 1, 0))
        }
        // The app reloads the timeline whenever the tickets change; this is only a fallback.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 3600))))
    }
}

extension NextFilm {
    static let sample = NextFilm(group: "00000000-0000-0000-0000-000000000000", title: "Perfect Days", venue: "Metrograph",
                                 start: Date().addingTimeInterval(5 * 3600), ends: Date().addingTimeInterval(7 * 3600),
                                 time: "7:30 PM", seats: ["F9", "F10"], tickets: 2, runtime: 124)
}

// MARK: - Look

private enum W {
    static func hex(_ v: UInt32, _ a: Double = 1) -> Color { Color(red: Double(v >> 16 & 255) / 255, green: Double(v >> 8 & 255) / 255, blue: Double(v & 255) / 255, opacity: a) }
    static let bg = hex(0x150b06), surface = hex(0x24130a), ink = hex(0xf6e9da), muted = hex(0xd8bea8)
    static let amber = hex(0xffc98f), accent = hex(0xef8a3c), onAccent = hex(0x1c0d05), paper = hex(0xfbf4ea)
    static func serif(_ s: CGFloat) -> Font { .custom("InstrumentSerif-Regular", size: s) }
    static func sans(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .custom("Geist", size: s).weight(w) }
    static func mono(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .custom("Geist Mono", size: s).weight(w) }
    static func image(_ url: URL?) -> UIImage? { url.flatMap { UIImage(contentsOfFile: $0.path) } }
}

/// The app's ticket outline (Theme.StubShape): rounded corners, a half-circle bitten out of
/// each side at `at`.
private struct Stub: Shape {
    var corner: CGFloat = 18, notch: CGFloat = 9, at: CGFloat = 0.5

    func path(in r: CGRect) -> Path {
        let c = min(corner, min(r.width, r.height) / 2)
        let y = r.minY + r.height * at
        return Path(roundedRect: r, cornerRadius: c, style: .continuous)
            .subtracting(Path(ellipseIn: CGRect(x: r.minX - notch, y: y - notch, width: notch * 2, height: notch * 2)))
            .subtracting(Path(ellipseIn: CGRect(x: r.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2)))
    }
}

/// Dashed tear line, across or down.
private struct Tear: View {
    var vertical = false
    var body: some View {
        GeometryReader { g in
            Path { p in
                if vertical { p.move(to: CGPoint(x: 0.75, y: 0)); p.addLine(to: CGPoint(x: 0.75, y: g.size.height)) }
                else { p.move(to: CGPoint(x: 0, y: 0.75)); p.addLine(to: CGPoint(x: g.size.width, y: 0.75)) }
            }
            .stroke(W.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        .frame(width: vertical ? 1.5 : nil, height: vertical ? nil : 1.5)
    }
}

private struct Poster: View {
    let film: NextFilm
    /// The film mark on the gradient; off where text sits on top of the poster.
    var mark = true
    @Environment(\.widgetRenderingMode) private var mode
    var body: some View {
        if let img = W.image(NextFilmStore.poster(film.group)) {
            // Filled into whatever space it's given, never sizing the layout itself. In the Clear
            // and Tinted Home Screens a plain image is drawn as a solid silhouette (a white box);
            // desaturated it stays a picture.
            Color.clear.overlay {
                Image(uiImage: img).resizable().widgetAccentedRenderingMode(.accentedDesaturated).scaledToFill()
            }
            .clipped()
        } else {
            // No poster: the ticket's gradient with a film mark (the title is already beside it).
            // Clear and Tinted keep only a shape's opacity, so the gradient would be a white box.
            ZStack {
                if mode == .fullColor { StubGradient(seed: film.group) } else { Color.white.opacity(0.08) }
                if mark { Image(systemName: "film").font(.system(size: 26, weight: .light)).foregroundStyle(W.ink.opacity(0.55)) }
            }
        }
    }
}

/// The film's logo if TMDb has one, the title in serif otherwise.
private struct TitleMark: View {
    let film: NextFilm
    var size: CGFloat
    var lines = 2
    var alignment: Alignment = .leading
    var body: some View {
        if let img = W.image(NextFilmStore.logo(film.group)) {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: size * 1.4, alignment: alignment)
                .shadow(color: .black.opacity(0.55), radius: 6)
        } else {
            Text(film.title).font(W.serif(size)).foregroundStyle(W.ink)
                .lineLimit(lines).minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }
}

/// "in 2 hr, 14 min" in the last day; "in 2 days" further out.
private struct When: View {
    let film: NextFilm
    let now: Date
    var body: some View {
        if film.start <= now {
            Text("Now showing")
        } else if film.start.timeIntervalSince(now) < 86400 {
            Text("in \(film.start, style: .relative)")
        } else {
            // "in 2 days": the day itself is already in the eyebrow.
            Text(film.start.formatted(.relative(presentation: .named)))
        }
    }
}

private func field(_ label: String, _ value: String, size: CGFloat = 14) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(label).font(W.sans(8.5, .medium)).tracking(0.9).foregroundStyle(W.muted)
        Text(value.isEmpty ? "—" : value).font(W.mono(size, .medium)).foregroundStyle(W.ink).lineLimit(1).minimumScaleFactor(0.6)
    }
}

private func seatsLabel(_ f: NextFilm) -> String {
    f.seats.isEmpty ? (f.tickets > 1 ? "×\(f.tickets)" : "") : f.seats.joined(separator: " ")
}

// MARK: - Views

struct NextFilmView: View {
    let entry: NextFilmEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    /// Full colour on the default Home Screen. Clear and Tinted (accented) draw every shape and
    /// colour as the one tint at its opacity, so dark fades and filled pills turn into white
    /// blocks there: they're dropped or made faint.
    private var full: Bool { mode == .fullColor }
    private func fill(_ c: Color) -> Color { full ? c : .white.opacity(0.2) }

    var body: some View {
        Group {
            if let f = entry.film {
                switch family {
                case .systemSmall: small(f)
                case .systemMedium: medium(f)
                case .systemLarge: large(f)
                case .accessoryRectangular: rectangular(f)
                case .accessoryInline: inline(f)
                default: medium(f)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) { W.bg }
        .widgetURL(entry.film.map { URL(string: "ndpass://ticket?group=\($0.group)")! } ?? URL(string: "ndpass://ticket")!)
    }

    // Small: the poster, full bleed, with a stub of the details along the bottom.
    private func small(_ f: NextFilm) -> some View {
        ZStack(alignment: .bottom) {
            Poster(film: f, mark: false).opacity(full ? 1 : 0.45)
            if full {
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: W.bg.opacity(0.75), location: 0.6), .init(color: W.bg, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(f.dayWord(now: entry.date)).font(W.mono(9.5, .medium)).tracking(1.3).foregroundStyle(W.amber).widgetAccentable()
                Text(f.title).font(W.serif(22)).foregroundStyle(W.ink).lineLimit(2).minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    Text(f.time).font(W.mono(11, .medium)).foregroundStyle(W.onAccent)
                        .padding(.horizontal, 7).padding(.vertical, 2.5).background(fill(W.accent), in: Capsule())
                    if !f.seats.isEmpty {
                        Text(f.seats.joined(separator: " ")).font(W.mono(11)).foregroundStyle(W.ink).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    // Medium: a ticket. Poster on the stub end, details on the body, torn down the middle.
    private func medium(_ f: NextFilm) -> some View {
        HStack(spacing: 0) {
            Poster(film: f)
                .frame(width: 104)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("ADMIT \(max(f.tickets, 1))").font(W.mono(8, .semibold)).tracking(1).foregroundStyle(W.onAccent)
                        .padding(.horizontal, 6).padding(.vertical, 3).background(fill(W.paper), in: Capsule())
                        .padding(8)
                }
                .padding(10)
            Tear(vertical: true).padding(.vertical, 14)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(f.eyebrow(now: entry.date)).font(W.mono(9.5, .medium)).tracking(1.2).foregroundStyle(W.amber).lineLimit(1)
                        .widgetAccentable()
                    Spacer(minLength: 4)
                    if entry.more > 0 {
                        Text("+\(entry.more)").font(W.mono(9.5)).foregroundStyle(W.muted)
                    }
                }
                TitleMark(film: f, size: 30).padding(.top, 6)
                Spacer(minLength: 4)
                When(film: f, now: entry.date).font(W.sans(12, .medium)).foregroundStyle(W.accent).lineLimit(1)
                    .widgetAccentable().padding(.bottom, 8)
                HStack(alignment: .top, spacing: 14) {
                    field("TIME", f.time)
                    field(f.seats.count > 1 ? "SEATS" : "SEAT", seatsLabel(f))
                    if let r = f.runtimeLabel { field("RUNS", r) }
                }
            }
            .padding(.vertical, 14).padding(.leading, 14).padding(.trailing, 16)
        }
        .background(alignment: .leading) {
            // The poster's colour bleeding into the ticket, faintly (colour only).
            if full { Poster(film: f).blur(radius: 30).opacity(0.35).overlay(W.bg.opacity(0.45)) }
        }
    }

    // Large: the poster as the screen, a paper stub across the bottom.
    private func large(_ f: NextFilm) -> some View {
        ZStack(alignment: .bottom) {
            Poster(film: f, mark: false).opacity(full ? 1 : 0.45)
            if full {
                LinearGradient(stops: [.init(color: W.bg.opacity(0.45), location: 0), .init(color: .clear, location: 0.18),
                                       .init(color: .clear, location: 0.38), .init(color: W.bg.opacity(0.9), location: 0.7), .init(color: W.bg, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("NDPass").font(W.serif(20)).foregroundStyle(W.ink)
                    Spacer()
                    Text(f.dayWord(now: entry.date)).font(W.mono(10, .medium)).tracking(1.3).foregroundStyle(W.onAccent)
                        .padding(.horizontal, 9).padding(.vertical, 4).background(fill(W.accent), in: Capsule())
                        .widgetAccentable()
                }
                Spacer()
                TitleMark(film: f, size: 44, lines: 2).padding(.bottom, 4)
                if !f.venue.isEmpty {
                    Text(f.venue).font(W.sans(14)).foregroundStyle(W.ink.opacity(0.85)).lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 10) {
                    When(film: f, now: entry.date).font(W.sans(12, .semibold)).foregroundStyle(W.accent).lineLimit(1)
                        .widgetAccentable()
                    Tear().padding(.horizontal, -4)
                    HStack(alignment: .top, spacing: 0) {
                        field("TIME", f.time, size: 16).frame(maxWidth: .infinity, alignment: .leading)
                        field(f.seats.count > 1 ? "SEATS" : "SEAT", seatsLabel(f), size: 16).frame(maxWidth: .infinity, alignment: .leading)
                        field("DATE", f.start.formatted(.dateTime.month(.abbreviated).day()), size: 16).frame(maxWidth: .infinity, alignment: .leading)
                        if let r = f.runtimeLabel { field("RUNS", r, size: 16).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }
                .padding(14)
                .background(full ? W.surface.opacity(0.72) : .white.opacity(0.1), in: Stub(corner: 16, notch: 8, at: 0.36))
                .overlay(Stub(corner: 16, notch: 8, at: 0.36).stroke(W.ink.opacity(0.12), lineWidth: 1))
                .padding(.top, 12)
            }
            .padding(16)
        }
    }

    // Lock Screen.
    private func rectangular(_ f: NextFilm) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(f.dayWord(now: entry.date) + (f.venue.isEmpty ? "" : " · \(f.venue)")).font(W.mono(10, .medium)).tracking(0.6).lineLimit(1)
                .widgetAccentable()
            Text(f.title).font(W.serif(19)).lineLimit(1).minimumScaleFactor(0.7)
            Text([f.time, f.seats.isEmpty ? nil : f.seats.joined(separator: " ")].compactMap { $0 }.joined(separator: " · "))
                .font(W.mono(11)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ f: NextFilm) -> some View {
        Label("\(f.title) · \(f.time)", systemImage: "film")
    }

    private var empty: some View {
        Group {
            if family == .accessoryRectangular || family == .accessoryInline {
                Text("No films coming up").font(W.sans(12))
            } else {
                ZStack {
                    if full { StubGradient(seed: "ndpass").opacity(0.55) }
                    VStack(spacing: 6) {
                        Image(systemName: "film").font(.system(size: 22, weight: .light)).foregroundStyle(W.amber).widgetAccentable()
                        Text("Nothing showing").font(W.serif(family == .systemSmall ? 22 : 28)).foregroundStyle(W.ink)
                        Text("Add a ticket to NDPass").font(W.sans(11)).foregroundStyle(W.muted)
                    }
                    .multilineTextAlignment(.center)
                }
            }
        }
    }
}

#Preview(as: .systemMedium) { NextFilmWidget() } timeline: { NextFilmEntry(date: .now, film: .sample, more: 2) }
#Preview(as: .systemSmall) { NextFilmWidget() } timeline: { NextFilmEntry(date: .now, film: .sample, more: 0) }
#Preview(as: .systemLarge) { NextFilmWidget() } timeline: { NextFilmEntry(date: .now, film: .sample, more: 1) }

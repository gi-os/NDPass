import SwiftUI
import UIKit

/// The projection-room palette: espresso ground, cream type, burnt orange from the ND icon.
enum Theme {
    static func hex(_ v: UInt32, _ a: Double = 1) -> Color {
        Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: a)
    }
    static let bg = hex(0x150b06)
    static let surface = hex(0x24130a)
    static let ink = hex(0xf6e9da)
    static let muted = hex(0xd8bea8)
    static let amber = hex(0xffc98f)
    static let accent = hex(0xef8a3c)
    static let onAccent = hex(0x1c0d05)
    static let paper = hex(0xfbf4ea)
    static let paperInk = hex(0x1a0f08)
    static let paperMuted = hex(0x6b4a33)
    // older names still used around the app
    static let cream = ink
    static let orange = accent
    static let dim = muted

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size, relativeTo: .largeTitle)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Geist", size: size, relativeTo: .body).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Geist Mono", size: size, relativeTo: .body).weight(weight)
    }

    /// Serif large titles in every navigation bar.
    static func applyNavigationFonts() {
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        let cream = UIColor(red: 0.965, green: 0.914, blue: 0.855, alpha: 1)
        if let big = UIFont(name: "InstrumentSerif-Regular", size: 40) { a.largeTitleTextAttributes = [.font: big, .foregroundColor: cream] }
        if let small = UIFont(name: "InstrumentSerif-Regular", size: 22) { a.titleTextAttributes = [.font: small, .foregroundColor: cream] }
        UINavigationBar.appearance().standardAppearance = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
        UINavigationBar.appearance().compactAppearance = a
    }
}

/// A ticket: rounded corners and a half-circle notch bitten out of each side.
struct StubShape: Shape {
    var corner: CGFloat = 28
    var notch: CGFloat = 13
    var at: CGFloat = 0.5

    func path(in r: CGRect) -> Path {
        let c = min(corner, min(r.width, r.height) / 2)
        let n = min(notch, r.height / 4)
        let y = r.minY + r.height * at
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - c, y: r.minY + c), radius: c, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: y - n))
        p.addArc(center: CGPoint(x: r.maxX, y: y), radius: n, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addArc(center: CGPoint(x: r.maxX - c, y: r.maxY - c), radius: c, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + c, y: r.maxY - c), radius: c, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: y + n))
        p.addArc(center: CGPoint(x: r.minX, y: y), radius: n, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addArc(center: CGPoint(x: r.minX + c, y: r.minY + c), radius: c, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Liquid Glass on iOS 26, a frosted material before it.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
    }

    @available(iOS 26.0, *)
    private var glass: SwiftUI.Glass {
        var g = SwiftUI.Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

extension View {
    func glass(_ radius: CGFloat = 18) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }
    func glass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

/// The tear line across a stub.
struct Perforation: View {
    var color: Color = Theme.ink.opacity(0.35)
    var body: some View {
        GeometryReader { g in
            Path { p in p.move(to: CGPoint(x: 0, y: 0.75)); p.addLine(to: CGPoint(x: g.size.width, y: 0.75)) }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
        .frame(height: 1.5)
    }
}

/// The film's art, as large as it goes: the poster, drawn art for a game or concert, the
/// cropped stub, or the photo.
struct CoverArt: View {
    let pass: Pass?
    var preferBackdrop = false

    var body: some View {
        GeometryReader { g in
            Group {
                if let p = pass, let url = preferBackdrop ? (p.backdropURL ?? p.bigPosterURL) : (p.bigPosterURL ?? p.backdropURL) {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() } else { local }
                    }
                } else { local }
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipped()
        }
    }

    @ViewBuilder private var local: some View {
        // Event art (a matchup card, a show poster) if we made one; otherwise a gradient.
        // The photo of the ticket itself stays in the ticket view, not on the cover.
        if let p = pass, let d = p.art, let img = UIImage(data: d) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            StubGradient(seed: pass?.group.uuidString ?? "ndpass")
        }
    }
}

/// Small art for lists and grids; kept for older call sites.
struct PassArt: View {
    let pass: Pass
    var body: some View { CoverArt(pass: pass) }
}

struct FieldLabel: View {
    let title: String
    let value: String
    var mono = false
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(Theme.sans(11, .medium)).tracking(1).foregroundStyle(Theme.muted)
            Text(value.isEmpty ? "—" : value).font(mono ? Theme.mono(17) : Theme.sans(16, .medium)).foregroundStyle(Theme.ink).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "IN 3H 12M", "IN 42 MIN", "NOW", or nothing for a past showing.
enum Countdown {
    static func short(to start: Date?, now: Date = Date()) -> String? {
        guard let start else { return nil }
        let s = Int(start.timeIntervalSince(now))
        if s < -3 * 3600 { return nil }
        if s <= 0 { return "NOW" }
        let h = s / 3600, m = (s % 3600) / 60
        if s < 3600 { return "IN \(max(1, m)) MIN" }
        if h < 48 { return "IN \(h)H \(m)M" }
        return "IN \(h / 24) DAYS"
    }

    static func clock(to start: Date?, now: Date = Date()) -> String {
        guard let start else { return "--:--" }
        let s = max(0, Int(start.timeIntervalSince(now)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    static func eyebrow(for p: Pass, now: Date = Date()) -> String {
        guard let start = p.start else { return PassTimes.humanDate(p.date)?.uppercased() ?? "NO DATE YET" }
        let cal = Calendar.current
        let prefix: String
        if cal.isDateInToday(start) { prefix = "TONIGHT" }
        else if cal.isDateInTomorrow(start) { prefix = "TOMORROW" }
        else { prefix = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased() }
        if let c = short(to: start, now: now), cal.isDateInToday(start) || cal.isDateInTomorrow(start) { return "\(prefix) · \(c)" }
        return prefix
    }
}

/// A ticket stub cut across: notches bitten out of the top and bottom edges where it tears.
struct TornStubShape: Shape {
    var corner: CGFloat = 18
    var notch: CGFloat = 10
    var atX: CGFloat = 0.7

    func path(in r: CGRect) -> Path {
        let c = min(corner, min(r.width, r.height) / 2)
        let n = min(notch, r.width / 8)
        let x = r.minX + r.width * atX
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: x - n, y: r.minY))
        p.addArc(center: CGPoint(x: x, y: r.minY), radius: n, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - c, y: r.minY + c), radius: c, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addArc(center: CGPoint(x: r.maxX - c, y: r.maxY - c), radius: c, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: x + n, y: r.maxY))
        p.addArc(center: CGPoint(x: x, y: r.maxY), radius: n, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + c, y: r.maxY - c), radius: c, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addArc(center: CGPoint(x: r.minX + c, y: r.minY + c), radius: c, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// The film's title logo from TMDB, or its title set in the serif when there's no logo.
struct TitleMark: View {
    let pass: Pass
    var maxHeight: CGFloat = 60
    var fallbackSize: CGFloat = 30
    var alignment: Alignment = .center

    var body: some View {
        Group {
            if let u = pass.logoURL {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: alignment)
                } placeholder: { fallback }
            } else { fallback }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: alignment)
        .shadow(color: .black.opacity(0.65), radius: 10, y: 2)
        .accessibilityLabel(pass.title)
    }

    private var fallback: some View {
        // Titles read off a ticket in all lowercase get their capitals back.
        Text(pass.title == pass.title.lowercased() ? (PassTimes.titleCase(pass.title) ?? pass.title) : pass.title).font(Theme.serif(fallbackSize)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.5)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
    }
}

/// Plex-style ticket art: the textless backdrop with the title logo over it.
struct TicketArt: View {
    let pass: Pass
    var logoHeight: CGFloat = 60
    var alignment: Alignment = .center

    var body: some View {
        ZStack(alignment: alignment) {
            CoverArt(pass: pass, preferBackdrop: true)
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            TitleMark(pass: pass, maxHeight: logoHeight, fallbackSize: logoHeight * 0.5, alignment: alignment)
                .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .clipped()
    }
}

/// A ticket in a list: backdrop and logo on the admission part, the date and time on the
/// torn-off end.
struct TicketStub: View {
    let passes: [Pass]
    var height: CGFloat = 150

    var body: some View {
        let p = passes[0]
        let stubW = (height * 0.62).rounded()
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(spacing: 0) {
                    TicketArt(pass: p, logoHeight: height * 0.36)
                        .frame(width: g.size.width - stubW)
                    VStack(spacing: 2) {
                        Text(month(p)).font(Theme.mono(11, .medium)).tracking(1.4).foregroundStyle(Theme.amber)
                        Text(dayNum(p)).font(Theme.serif(height * 0.3)).foregroundStyle(Theme.ink)
                        Text(p.time.isEmpty ? " " : p.time).font(Theme.mono(11)).foregroundStyle(Theme.ink.opacity(0.85))
                        if passes.count > 1 { Text("×\(passes.count)").font(Theme.mono(11)).foregroundStyle(Theme.muted).padding(.top, 2) }
                    }
                    .frame(width: stubW)
                    .frame(maxHeight: .infinity)
                    .background(Theme.surface)
                    .overlay(alignment: .leading) {
                        Path { path in path.move(to: CGPoint(x: 0.75, y: 10)); path.addLine(to: CGPoint(x: 0.75, y: height - 10)) }
                            .stroke(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                .clipShape(TornStubShape(corner: 18, notch: 9, atX: (g.size.width - stubW) / max(1, g.size.width)))
            }
            .frame(height: height)
            if !p.venue.isEmpty {
                Text(p.venue).font(Theme.sans(13)).foregroundStyle(Theme.muted).lineLimit(1).padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func month(_ p: Pass) -> String {
        PassTimes.day(p.date).map { $0.formatted(.dateTime.month(.abbreviated)).uppercased() } ?? "—"
    }
    private func dayNum(_ p: Pass) -> String {
        PassTimes.day(p.date).map { String(Calendar.current.component(.day, from: $0)) } ?? "?"
    }
}

/// A ticket's date and time as real pickers, stored as the "yyyy-MM-dd" and "7:30 PM"
/// strings the rest of the app reads. Empty until you tap to add one.
enum WhenFormat {
    static func formatter(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = Locale(identifier: "en_US_POSIX"); d.dateFormat = f; return d
    }
    static let day = formatter("yyyy-MM-dd")
    static let clock = formatter("h:mm a")

    static func date(_ s: String) -> Date? { day.date(from: s) }
    static func time(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces).uppercased()
        guard let parsed = clock.date(from: t) ?? formatter("H:mm").date(from: t) else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: parsed)
        return Calendar.current.date(bySettingHour: c.hour ?? 19, minute: c.minute ?? 0, second: 0, of: Date())
    }
}

struct DateField: View {
    var label = "Date"
    @Binding var text: String

    var body: some View {
        let bound = Binding<Date>(
            get: { WhenFormat.date(text) ?? Date() },
            set: { text = WhenFormat.day.string(from: $0) })
        HStack {
            Text(label)
            Spacer()
            if WhenFormat.date(text) != nil {
                DatePicker(label, selection: bound, displayedComponents: .date).labelsHidden()
            } else {
                Button(text.isEmpty ? "Add date" : "Fix “\(text)”") { text = WhenFormat.day.string(from: Date()) }
                    .tint(Theme.accent)
            }
        }
    }
}

struct TimeField: View {
    var label = "Time"
    @Binding var text: String

    var body: some View {
        let bound = Binding<Date>(
            get: { WhenFormat.time(text) ?? Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())! },
            set: { text = WhenFormat.clock.string(from: $0) })
        HStack {
            Text(label)
            Spacer()
            if WhenFormat.time(text) != nil {
                DatePicker(label, selection: bound, displayedComponents: .hourAndMinute).labelsHidden()
                    .environment(\.locale, Locale(identifier: "en_US"))   // AM/PM even on a 24-hour phone
            } else {
                Button(text.isEmpty ? "Add time" : "Fix “\(text)”") { text = "7:30 PM" }.tint(Theme.accent)
            }
        }
    }
}

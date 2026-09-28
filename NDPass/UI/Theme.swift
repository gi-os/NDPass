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
        if let p = pass, let d = p.art ?? p.crop ?? p.photo, let img = UIImage(data: d) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [Theme.hex(0x3a1d10), Theme.bg], startPoint: .top, endPoint: .bottom)
                Circle().fill(Theme.accent.opacity(0.55)).frame(width: 160).offset(x: 60, y: -40).blur(radius: 2)
            }
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

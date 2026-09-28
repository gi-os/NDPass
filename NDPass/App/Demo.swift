import SwiftUI
import SwiftData

/// Sample tickets for the App Store screenshots. On when launched with `-demo` (or by
/// fastlane snapshot); the real library is never touched — demo data lives in memory.
enum Demo {
    static var active: Bool {
        let a = ProcessInfo.processInfo.arguments
        return a.contains("-demo") || a.contains("-FASTLANE_SNAPSHOT")
    }

    @MainActor static func container() -> ModelContainer {
        let c = try! ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        seed(c.mainContext)
        return c
    }

    private static func day(_ offset: Int, _ time: String) -> (String, String) {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return (f.string(from: d), time)
    }

    @MainActor static func seed(_ ctx: ModelContext) {
        let soon = Date().addingTimeInterval(3 * 3600 + 12 * 60)
        let tf = DateFormatter(); tf.locale = Locale(identifier: "en_US_POSIX"); tf.dateFormat = "h:mm a"
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        let tonight = (df.string(from: soon), tf.string(from: soon))
        let rows: [(String, EventKind, String, (String, String), [String], String, Art)] = [
            ("Low Tide", .movie, "Metrograph", tonight, ["F12", "F13"], "$17.00", .tide),
            ("The Quiet Year", .movie, "Film Forum", day(11, "7:30 PM"), ["H7"], "$16.00", .snow),
            ("Neon Almanac", .movie, "Angelika Film Center", day(19, "8:00 PM"), ["J4", "J5"], "$19.50", .neon),
            ("Harbor vs Ironside", .sports, "Riverside Arena", day(29, "7:30 PM"), ["Sec 112 Row 8"], "$145.00", .game),
            ("Paper Moons", .movie, "IFC Center", day(35, "9:15 PM"), ["E9"], "$18.00", .moons),
            ("Red Summer", .movie, "Film Forum", day(-16, "7:00 PM"), ["C3"], "$16.00", .sun),
            ("Dot Matrix", .movie, "Metrograph", day(-40, "9:45 PM"), ["B10"], "$17.00", .dots),
            ("The Quiet Year", .movie, "Nitehawk", day(-75, "6:30 PM"), ["D2"], "$15.00", .snow)
        ]
        for (title, kind, venue, when, seats, price, art) in rows {
            let group = UUID()
            for seat in seats {
                let p = Pass(title: title)
                p.group = group
                p.kind = kind
                p.venue = venue
                p.date = when.0
                p.time = when.1
                p.seat = seat
                p.price = price
                p.confidence = 0.96
                p.runtime = kind == .movie ? 118 : nil
                p.art = art == .game ? EventArt.matchCard("Harbor", "Ironside").jpegData(compressionQuality: 0.9) : poster(art)
                p.scannedCode = "NDP-\(title.prefix(3).uppercased())-\(seat.filter(\.isLetter))\(seat.filter(\.isNumber))-2026"
                p.scannedFormat = .qr
                p.overview = kind == .movie ? "A demo ticket for the App Store screenshots." : nil
                ctx.insert(p)
            }
        }
        try? ctx.save()
    }

    enum Art { case tide, snow, neon, moons, sun, dots, game }

    /// Abstract posters, drawn so no film's real artwork appears in the screenshots.
    static func poster(_ a: Art) -> Data? {
        let size = CGSize(width: 600, height: 900)
        let img = UIGraphicsImageRenderer(size: size).image { r in
            let c = r.cgContext
            let rect = CGRect(origin: .zero, size: size)
            func grad(_ colors: [UIColor], _ locs: [CGFloat]) {
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: locs)!
                c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            func hex(_ v: UInt32) -> UIColor { UIColor(red: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
            switch a {
            case .tide:
                grad([hex(0x2b1433), hex(0x8e3f3a), hex(0xe98a4f)], [0, 0.4, 0.55])
                hex(0x12303f).setFill(); c.fill(CGRect(x: 0, y: size.height * 0.56, width: size.width, height: size.height * 0.44))
                hex(0xffe2b8).setFill(); c.fillEllipse(in: CGRect(x: 330, y: 250, width: 120, height: 120))
            case .snow:
                grad([hex(0xe7ded2), hex(0xa79d95)], [0, 1])
                hex(0x1b1512).setFill(); c.fillEllipse(in: CGRect(x: 262, y: 400, width: 76, height: 76)); c.fillEllipse(in: CGRect(x: 225, y: 470, width: 150, height: 330))
            case .neon:
                grad([hex(0x12051f), hex(0x3d0c4c), hex(0x0b2f4b)], [0, 0.55, 1])
                hex(0xff56aa).withAlphaComponent(0.35).setFill()
                for x in stride(from: 0, to: 600, by: 26) { c.fill(CGRect(x: x, y: 0, width: 2, height: 900)) }
                hex(0x46dcff).withAlphaComponent(0.25).setFill()
                for y in stride(from: 0, to: 900, by: 26) { c.fill(CGRect(x: 0, y: y, width: 600, height: 2)) }
            case .moons:
                hex(0x2a1a12).setFill(); c.fill(rect)
                hex(0xf6e9da).setFill(); c.fillEllipse(in: CGRect(x: 80, y: 150, width: 260, height: 260))
                hex(0xd9692a).setFill(); c.fillEllipse(in: CGRect(x: 320, y: 480, width: 180, height: 180))
            case .sun:
                hex(0xf3e6c8).setFill(); c.fill(rect)
                hex(0x3e5a2e).setFill(); c.fill(CGRect(x: 0, y: 560, width: 600, height: 340))
                hex(0xe2483b).setFill(); c.fillEllipse(in: CGRect(x: 170, y: 190, width: 260, height: 260))
            case .dots, .game:
                hex(0x3b1a0e).setFill(); c.fill(rect)
                hex(0xf2a65a).setFill()
                for y in stride(from: 10, to: 900, by: 28) { for x in stride(from: 10, to: 600, by: 28) { c.fillEllipse(in: CGRect(x: x, y: y, width: 12, height: 12)) } }
            }
        }
        return img.jpegData(compressionQuality: 0.9)
    }
}

import SwiftUI

/// Art for a ticket with no poster or logo: an orange and brown gradient that's the same
/// every time for the same ticket, and different from the tickets next to it.
struct StubGradient: View {
    let seed: String

    private static let warm: [UInt32] = [0xef8a3c, 0xf2a65a, 0xd9692a, 0xc2562b, 0xffc98f, 0xe07b39, 0xb8612f, 0xf5b26b]
    private static let deep: [UInt32] = [0x3a1d10, 0x2a140a, 0x4a2412, 0x5a2d16, 0x1c0d05, 0x6b3419, 0x3b2314, 0x24110a]

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double(v >> 16 & 255) / 255, green: Double(v >> 8 & 255) / 255, blue: Double(v & 255) / 255)
    }

    /// FNV-1a, so the seed is stable across launches (String.hashValue isn't).
    private var bits: UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in seed.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    var body: some View {
        let h = bits
        let pick = { (shift: UInt64, n: Int) in Int((h >> shift) % UInt64(n)) }
        let a = Self.hex(Self.warm[pick(0, 8)])
        let b = Self.hex(Self.warm[pick(8, 8)])
        let d1 = Self.hex(Self.deep[pick(16, 8)])
        let d2 = Self.hex(Self.deep[pick(24, 8)])
        let angle = Double(pick(32, 360))
        let gx = 0.15 + Double(pick(40, 70)) / 100
        let gy = 0.1 + Double(pick(48, 50)) / 100
        let r = cos(angle * .pi / 180), s = sin(angle * .pi / 180)
        ZStack {
            LinearGradient(colors: [d1, d2], startPoint: UnitPoint(x: 0.5 - r / 2, y: 0.5 - s / 2), endPoint: UnitPoint(x: 0.5 + r / 2, y: 0.5 + s / 2))
            GeometryReader { g in
                let m = max(g.size.width, g.size.height)
                RadialGradient(colors: [a.opacity(0.95), b.opacity(0.45), .clear], center: UnitPoint(x: gx, y: gy), startRadius: 0, endRadius: m * 0.75)
                RadialGradient(colors: [b.opacity(0.35), .clear], center: UnitPoint(x: 1 - gx, y: 1 - gy * 0.6), startRadius: 0, endRadius: m * 0.5)
            }
        }
    }
}

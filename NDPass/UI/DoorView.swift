import SwiftUI

/// Warm white, full brightness, the code as big as it goes, and a chip per seat.
struct DoorView: View {
    let passes: [Pass]
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var saved: CGFloat = 0.5

    static func code(for p: Pass?) -> (UIImage, Bool)? {
        guard let p else { return nil }
        if let s = p.scannedCode, let f = p.scannedFormat, let img = Barcodes.render(s, as: f) { return (img, true) }
        // Only the code read off the ticket itself. Codes drawn from a booking reference
        // rarely scan, so NDPass doesn't make them; the stub photo goes to the door instead.
        return nil
    }

    var body: some View {
        let p = passes.indices.contains(index) ? passes[index] : passes.first
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    if let p { CoverArt(pass: p).frame(width: 58, height: 58).clipShape(StubShape(corner: 12, notch: 7, at: 0.62)) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p?.title ?? "").font(Theme.serif(28)).foregroundStyle(Theme.paperInk).lineLimit(2)
                        Text(subtitle(p)).font(Theme.sans(14)).foregroundStyle(Theme.paperMuted)
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                Group {
                    if let found = Self.code(for: p) {
                        Image(uiImage: found.0).interpolation(.none).resizable().scaledToFit()
                    } else if let d = p?.crop ?? p?.photo, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFit()
                    }
                }
                .padding(22)
                .frame(maxWidth: 340, maxHeight: 340)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Theme.paperInk.opacity(0.18), radius: 24, y: 14)
                if passes.count > 1 || !(p?.seat.isEmpty ?? true) {
                    HStack(spacing: 10) {
                        ForEach(Array(passes.enumerated()), id: \.offset) { i, t in
                            Button { withAnimation(.snappy) { index = i } } label: {
                                Text(t.seat.isEmpty ? "Ticket \(i + 1)" : t.seat).font(Theme.mono(22))
                                    .padding(.horizontal, 18).frame(height: 46)
                                    .foregroundStyle(i == index ? Theme.paper : Theme.paperInk)
                                    .background(i == index ? Theme.paperInk : Theme.hex(0xefe2d2), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Label("Brightness is up while this is open", systemImage: "sun.max").font(Theme.sans(14)).foregroundStyle(Theme.paperMuted)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Text("Done").font(Theme.sans(16, .medium)).foregroundStyle(Theme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(Capsule().stroke(Theme.hex(0xd8c4ae), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28).padding(.top, 30).padding(.bottom, 20)
        }
        .preferredColorScheme(.light)
        .onAppear { saved = UIScreen.main.brightness; UIScreen.main.brightness = 1 }
        .onDisappear { UIScreen.main.brightness = saved }
        .statusBarHidden()
    }

    private func subtitle(_ p: Pass?) -> String {
        guard let p else { return "" }
        var parts: [String] = []
        if !p.venue.isEmpty { parts.append(p.venue) }
        if let s = p.start { parts.append(s.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) }
        if !p.time.isEmpty { parts.append(p.time) }
        return parts.joined(separator: " · ")
    }
}

/// For propping the phone up: the countdown over the art on the top half, the code and the
/// controls on the bottom. On the iPhone Duo half folded, the halves meet at the hinge.
struct CountdownView: View {
    let passes: [Pass]
    @Environment(\.dismiss) private var dismiss
    @State private var door = false

    var body: some View {
        let p = passes.first
        GeometryReader { g in
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    CoverArt(pass: p, preferBackdrop: g.size.width > g.size.height)
                    LinearGradient(colors: [Theme.bg.opacity(0.15), Theme.bg.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Starts in").font(Theme.sans(18)).foregroundStyle(Theme.ink.opacity(0.85))
                        TimelineView(.periodic(from: .now, by: 1)) { c in
                            Text(Countdown.clock(to: p?.start, now: c.date)).font(Theme.serif(min(150, g.size.width * 0.3))).monospacedDigit()
                                .foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.5)
                        }
                        Text(p?.title ?? "").font(Theme.serif(40, italic: true)).foregroundStyle(Theme.ink).lineLimit(2)
                    }
                    .padding(32)
                }
                .frame(height: g.size.height / 2 - 1)
                .clipped()
                Rectangle().fill(Theme.ink.opacity(0.1)).frame(height: 2)
                HStack(alignment: .top, spacing: 24) {
                    CodeTile(passes: passes, side: min(220, g.size.width * 0.34))
                        .frame(maxWidth: min(220, g.size.width * 0.34), alignment: .leading)
                        .labelsHidden()
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            box(passes.count > 1 ? "Seats" : "Seat", Showings.seats(passes))
                            box("Time", p?.timeLabel ?? "")
                        }
                        Button { door = true } label: {
                            Text("Show at the door").font(Theme.sans(18, .semibold)).foregroundStyle(Theme.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 58).background(Theme.accent, in: Capsule())
                        }
                        if let v = p?.venue, !v.isEmpty {
                            Button { Maps.open(v) } label: {
                                Text("Directions").font(Theme.sans(16)).foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 54).glass(in: Capsule(), interactive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(28)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44).glass(in: Circle(), interactive: true)
            }
            .padding(20)
            .accessibilityLabel("Close")
        }
        .fullScreenCover(isPresented: $door) { DoorView(passes: passes) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .statusBarHidden()
    }

    private func box(_ t: String, _ v: String) -> some View {
        FieldLabel(title: t, value: v, mono: true).padding(16).glass(22)
    }
}

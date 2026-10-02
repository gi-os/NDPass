import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

@main
struct NDPassWidgets: WidgetBundle {
    var body: some Widget { CountdownLiveActivity() }
}

private enum C {
    static func hex(_ v: UInt32, _ a: Double = 1) -> Color { Color(red: Double(v >> 16 & 255) / 255, green: Double(v >> 8 & 255) / 255, blue: Double(v & 255) / 255, opacity: a) }
    static let bg = hex(0x140a05), ink = hex(0xf6e9da), muted = hex(0xd8bea8), amber = hex(0xffc98f), accent = hex(0xef8a3c), onAccent = hex(0x1c0d05), paper = hex(0xfbf4ea)
    static func serif(_ s: CGFloat) -> Font { .custom("InstrumentSerif-Regular", size: s) }
    static func sans(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font { .custom("Geist", size: s).weight(w) }
    static func mono(_ s: CGFloat) -> Font { .custom("Geist Mono", size: s) }
    static func image(_ url: URL?) -> UIImage? { url.flatMap { UIImage(contentsOfFile: $0.path) } }
}

private struct Backdrop: View {
    let group: String
    var body: some View {
        if let img = C.image(CountdownArt.backdrop(group)) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            StubGradient(seed: group)
        }
    }
}

/// The backdrop and logo the app put together at this size; the gradient if it isn't there.
private struct IslandTile: View {
    let group: String
    var body: some View {
        if let img = C.image(CountdownArt.island(group)) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            StubGradient(seed: group)
        }
    }
}

private struct Logo: View {
    let a: CountdownAttributes
    var height: CGFloat
    var body: some View {
        if let img = C.image(CountdownArt.logo(a.group)) {
            Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: height, alignment: .leading)
                .shadow(color: .black.opacity(0.6), radius: 6)
        } else {
            Text(a.title).font(C.serif(height * 0.8)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.5)
        }
    }
}

private func link(_ path: String, _ a: CountdownAttributes) -> URL { URL(string: "ndpass://\(path)?group=\(a.group)")! }

private func countdown(_ s: CountdownAttributes.ContentState) -> Text {
    Text(timerInterval: Date()...max(Date(), s.start), countsDown: true)
}

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownAttributes.self) { ctx in
            // Twenty minutes out the activity goes stale, which redraws it as the door card.
            Group {
                if ctx.isStale || ctx.state.start.timeIntervalSinceNow < 20 * 60 { DoorCard(ctx: ctx) } else { CountdownCard(ctx: ctx) }
            }
            .activityBackgroundTint(C.bg)
            .activitySystemActionForegroundColor(C.ink)
            .widgetURL(link("ticket", ctx.attributes))
        } dynamicIsland: { ctx in
            let a = ctx.attributes
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandTile(group: a.group)
                        .frame(width: 64, height: 40).clipShape(RoundedRectangle(cornerRadius: 8)).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(ctx.state).font(C.serif(30)).monospacedDigit().foregroundStyle(C.accent)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 120, alignment: .trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(a.title) · \(a.time)").font(C.sans(14, .semibold)).foregroundStyle(C.ink).lineLimit(1)
                            Text([a.seats.isEmpty ? nil : "Seats " + a.seats.joined(separator: " "), a.venue.isEmpty ? nil : a.venue].compactMap { $0 }.joined(separator: " · "))
                                .font(C.mono(11)).foregroundStyle(C.muted).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Link(destination: link(a.seller != nil ? "seller" : "door", a)) {
                            Text(a.seller.map { "Open \($0)" } ?? "Open ticket").font(C.sans(13, .semibold)).foregroundStyle(C.onAccent)
                                .padding(.horizontal, 14).frame(height: 34).background(C.accent, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                IslandTile(group: a.group).frame(width: 29, height: 18).clipShape(RoundedRectangle(cornerRadius: 5))
            } compactTrailing: {
                countdown(ctx.state).font(C.mono(12)).monospacedDigit().foregroundStyle(C.accent).frame(maxWidth: 58)
            } minimal: {
                ProgressView(timerInterval: a.windowStart...max(a.windowStart.addingTimeInterval(1), ctx.state.start), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular).tint(C.accent)
            }
            .keylineTint(C.accent)
            .widgetURL(link("ticket", a))
        }
    }
}

private struct CountdownCard: View {
    let ctx: ActivityViewContext<CountdownAttributes>
    var body: some View {
        let a = ctx.attributes
        ZStack {
            Backdrop(group: a.group)
            LinearGradient(colors: [C.bg.opacity(0.94), C.bg.opacity(0.7), C.bg.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.eyebrow).font(C.mono(10)).tracking(1.2).foregroundStyle(C.amber).lineLimit(1)
                        Logo(a: a, height: 34)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Starts in").font(C.sans(11)).foregroundStyle(C.muted)
                        countdown(ctx.state).font(C.serif(36)).monospacedDigit().foregroundStyle(C.ink)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 150, alignment: .trailing)
                    }
                }
                ProgressView(timerInterval: a.windowStart...max(a.windowStart.addingTimeInterval(1), ctx.state.start), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(C.accent)
                HStack(alignment: .bottom) {
                    HStack(spacing: 16) {
                        field("TIME", a.time)
                        if !a.seats.isEmpty { field(a.seats.count > 1 ? "SEATS" : "SEAT", a.seats.joined(separator: " ")) }
                    }
                    Spacer(minLength: 6)
                    Link(destination: link(a.seller != nil ? "seller" : "door", a)) {
                        Text(a.seller.map { "Open \($0)" } ?? "Open ticket").font(C.sans(13, .semibold)).foregroundStyle(C.onAccent)
                            .padding(.horizontal, 14).frame(height: 32).background(C.accent, in: Capsule())
                    }
                    Link(destination: link("directions", a)) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.ink)
                            .frame(width: 32, height: 32).background(C.ink.opacity(0.14), in: Circle())
                    }
                }
            }
            .padding(16)
        }
    }

    private func field(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t).font(C.sans(9, .medium)).tracking(0.8).foregroundStyle(C.muted)
            Text(v.isEmpty ? "—" : v).font(C.mono(14)).foregroundStyle(C.ink).lineLimit(1)
        }
    }
}

/// Doors open: the ticket's own code, right on the Lock Screen. For rotating-code sellers,
/// the button to their app instead.
private struct DoorCard: View {
    let ctx: ActivityViewContext<CountdownAttributes>
    var body: some View {
        let a = ctx.attributes
        ZStack {
            Backdrop(group: a.group)
            LinearGradient(colors: [C.bg.opacity(0.95), C.bg.opacity(0.75), C.bg.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DOORS OPEN · STARTS \(a.time)").font(C.mono(10)).tracking(1.2).foregroundStyle(C.amber).lineLimit(1)
                    Logo(a: a, height: 30)
                    HStack(spacing: 6) {
                        ForEach(Array(a.seats.prefix(4).enumerated()), id: \.offset) { i, seat in
                            Text(seat).font(C.mono(13)).padding(.horizontal, 9).padding(.vertical, 4)
                                .foregroundStyle(i == 0 ? C.onAccent : C.ink)
                                .background(i == 0 ? C.paper : C.ink.opacity(0.14), in: Capsule())
                        }
                    }
                    Text(a.venue).font(C.sans(11)).foregroundStyle(C.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let seller = a.seller {
                    Link(destination: link("seller", a)) {
                        Text("Open \(seller)").font(C.sans(14, .semibold)).foregroundStyle(C.onAccent)
                            .padding(.horizontal, 16).frame(height: 40).background(C.accent, in: Capsule())
                    }
                } else if let code = C.image(CountdownArt.code(a.group)) {
                    Image(uiImage: code).interpolation(.none).resizable().scaledToFit()
                        .padding(8).frame(width: 118, height: 118).background(C.paper, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Link(destination: link("door", a)) {
                        Text("Open ticket").font(C.sans(14, .semibold)).foregroundStyle(C.onAccent)
                            .padding(.horizontal, 16).frame(height: 40).background(C.accent, in: Capsule())
                    }
                }
            }
            .padding(16)
        }
    }
}

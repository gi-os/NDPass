import SwiftUI
import SwiftData

/// The next showing, as large as it goes: cover art behind a glass stub with the countdown,
/// seats and the button to show the ticket. On a wide window (the iPhone Duo's inner display)
/// the upcoming list takes the left half and the ticket the right, split at the hinge.
struct TonightView: View {
    @Query(sort: \Pass.createdAt) private var passes: [Pass]
    @State private var path: [UUID] = []
    @State private var selected: UUID?

    private var upcoming: [[Pass]] { Showings.groups(passes, archived: false) }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 700 { split(geo) } else { phone }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: phone

    private var phone: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    hero(upcoming.first)
                    if upcoming.count > 1 { comingUp(Array(upcoming.dropFirst())) }
                    Color.clear.frame(height: 120)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { DetailView(group: $0) }
        }
    }

    private func hero(_ g: [Pass]?) -> some View {
        ZStack(alignment: .top) {
            // Pulling down past the top zooms the art to fill instead of showing black above it.
            CoverArt(pass: g?.first, preferBackdrop: g?.first?.backdropPath != nil).frame(height: 560).frame(maxWidth: .infinity)
                .visualEffect { content, proxy in
                    let pull = max(0, proxy.frame(in: .scrollView(axis: .vertical)).minY)
                    return content.scaleEffect(1 + pull / 560, anchor: .bottom)
                }
            // The fade into the page rides with the art's bottom edge.
            LinearGradient(stops: [.init(color: .clear, location: 0.25),
                                   .init(color: Theme.bg.opacity(0.85), location: 0.78), .init(color: Theme.bg, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 560)
            // Pulling down past the top: the shade behind the logo and + and the bar itself stay
            // pinned to the top of the screen; only the art stretches under them.
            LinearGradient(colors: [Theme.bg.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .visualEffect { content, proxy in
                    content.offset(y: -max(0, proxy.frame(in: .scrollView(axis: .vertical)).minY))
                }
                .allowsHitTesting(false)
            VStack(spacing: 0) {
                topBar.padding(.top, 62).padding(.horizontal, 20)
                    .visualEffect { content, proxy in
                        content.offset(y: -max(0, proxy.frame(in: .scrollView(axis: .vertical)).minY))
                    }
                Group {
                    if let p = g?.first, p.logoURL != nil {
                        TitleMark(pass: p, maxHeight: 96, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 32)
                    } else { Color.clear }
                }
                .frame(height: 168, alignment: .bottom)
                .padding(.bottom, 12)
                if let g { stub(g).padding(.horizontal, 16) } else { empty.padding(.horizontal, 16) }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("NDPass").font(Theme.serif(36)).foregroundStyle(Theme.ink)
            Spacer()
            ScanMenu(onAdded: { p in if !p.isArchived { path = [p.group] } }) {
                Image(systemName: "plus").font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46).glass(in: Circle(), interactive: true)
            }
            .accessibilityLabel("Scan a ticket")
        }
    }

    private func stub(_ g: [Pass]) -> some View {
        let p = g[0]
        return VStack(alignment: .leading, spacing: 14) {
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                HStack {
                    Text(Countdown.eyebrow(for: p, now: ctx.date)).font(Theme.mono(12)).tracking(1.4).foregroundStyle(Theme.amber)
                    Spacer()
                    if g.count > 1 {
                        Text("\(g.count) tickets").font(Theme.sans(12)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.ink.opacity(0.14), in: Capsule())
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if p.logoURL == nil {
                    Text(p.title).font(Theme.serif(48)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.6)
                } else {
                    Text(p.title).font(Theme.sans(18, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                }
                if !p.venue.isEmpty { Text(p.venue).font(Theme.sans(15)).foregroundStyle(Theme.ink.opacity(0.85)) }
            }
            Perforation().padding(.horizontal, -6).padding(.vertical, 4)
            HStack(alignment: .top, spacing: 8) {
                FieldLabel(title: "Time", value: p.timeLabel, mono: true)
                FieldLabel(title: g.count > 1 ? "Seats" : "Seat", value: Showings.seats(g), mono: true)
                FieldLabel(title: "Date", value: p.start.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? (p.dateTBD ? "TBD" : p.date), mono: true)
            }
            HStack(spacing: 10) {
                if let seller = p.seller, seller.rotatingCode, !g.contains(where: { $0.scannedCode != nil }) {
                    Button { Seller.open(p) } label: {
                        Text("Open in \(seller.name)").font(Theme.sans(16, .semibold)).foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 50).background(Theme.accent, in: Capsule())
                    }
                    NavigationLink(value: p.group) {
                        Image(systemName: "ticket").font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
                            .frame(width: 50, height: 50).glass(in: Circle(), interactive: true)
                    }
                    .accessibilityLabel("Ticket details")
                } else {
                    NavigationLink(value: p.group) {
                        Text("Open ticket").font(Theme.sans(16, .semibold)).foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 50).background(Theme.accent, in: Capsule())
                    }
                }
                if !p.venue.isEmpty {
                    Button { Maps.open(p.venue) } label: {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
                            .frame(width: 50, height: 50).glass(in: Circle(), interactive: true)
                    }
                    .accessibilityLabel("Directions to \(p.venue)")
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 20)
        .glass(in: StubShape(corner: 28, notch: 14, at: 0.58))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NO TICKETS YET").font(Theme.mono(12)).tracking(1.4).foregroundStyle(Theme.amber)
            Text("Photograph a stub").font(Theme.serif(44)).foregroundStyle(Theme.ink)
            Text("Tap + and point the camera at a ticket, or pick a screenshot. Claude reads the film, theater, date, time, seat and price.")
                .font(Theme.sans(15)).foregroundStyle(Theme.ink.opacity(0.85))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(in: StubShape(corner: 28, notch: 14, at: 0.5))
    }

    private func comingUp(_ gs: [[Pass]]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming up").font(Theme.serif(28)).foregroundStyle(Theme.ink).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(gs, id: \.first!.group) { g in
                        NavigationLink(value: g[0].group) { StubThumb(passes: g, height: 118).frame(width: 128) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 28)
    }

    // MARK: iPhone Duo inner display

    private func split(_ geo: GeometryProxy) -> some View {
        let half = geo.size.width / 2
        return HStack(spacing: 0) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("NDPass").font(Theme.serif(46)).foregroundStyle(Theme.ink)
                            Spacer()
                            ScanMenu(onAdded: { p in selected = p.group }) {
                                Label("Scan a stub", systemImage: "plus").font(Theme.sans(15, .semibold)).foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 18).frame(height: 46).glass(in: Capsule(), interactive: true)
                            }
                        }
                        if upcoming.isEmpty { Text("No upcoming tickets.").font(Theme.sans(16)).foregroundStyle(Theme.muted) }
                        ForEach(upcoming, id: \.first!.group) { g in
                            Button { selected = g[0].group } label: { TicketCard(passes: g, selected: (selected ?? upcoming.first?.first?.group) == g[0].group) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 32).padding(.top, 40).padding(.bottom, 60)
                }
                .background(Theme.bg)
                .toolbar(.hidden, for: .navigationBar)
            }
            .frame(width: half - 12)
            // Nothing sits on the hinge.
            Rectangle().fill(Theme.ink.opacity(0.06)).frame(width: 24)
            NavigationStack {
                if let id = selected ?? upcoming.first?.first?.group { DetailView(group: id).id(id) }
                else { Theme.bg.overlay(Text("Pick a ticket").font(Theme.serif(30)).foregroundStyle(Theme.muted)) }
            }
            .frame(width: half - 12)
        }
    }
}

/// Directions in Apple Maps or Google Maps. Google Maps is the default when it's installed;
/// Settings can change it. Without the app, Google opens in the browser.
enum Maps {
    enum App: String, CaseIterable { case apple, google
        var title: String { self == .apple ? "Apple Maps" : "Google Maps" }
    }

    static var googleInstalled: Bool { UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) }

    static var preferred: App {
        get { Store.defaults.string(forKey: "mapsApp").flatMap(App.init(rawValue:)) ?? (googleInstalled ? .google : .apple) }
        set { Store.defaults.set(newValue.rawValue, forKey: "mapsApp") }
    }

    static func open(_ venue: String) {
        switch preferred {
        case .google:
            if googleInstalled, var c = URLComponents(string: "comgooglemaps://") {
                c.queryItems = [URLQueryItem(name: "daddr", value: venue), URLQueryItem(name: "directionsmode", value: "transit")]
                if let u = c.url { UIApplication.shared.open(u); return }
            }
            var c = URLComponents(string: "https://www.google.com/maps/dir/")!
            c.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: venue), URLQueryItem(name: "travelmode", value: "transit")]
            if let u = c.url { UIApplication.shared.open(u) }
        case .apple:
            var c = URLComponents(string: "maps://")!
            c.queryItems = [URLQueryItem(name: "daddr", value: venue)]
            if let u = c.url { UIApplication.shared.open(u) }
        }
    }
}

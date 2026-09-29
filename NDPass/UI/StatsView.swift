import SwiftUI
import SwiftData
import Charts
import MapKit

/// Numbers about your nights out: records, what you go to, when, and where.
struct StatsView: View {
    @Query private var passes: [Pass]
    @State private var pins: [VenuePin] = []

    var body: some View {
        let s = Stats(passes)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        tile("\(s.visits)", s.visits == 1 ? "night out" : "nights out")
                        tile("\(s.tickets)", "tickets")
                    }
                    HStack(spacing: 14) {
                        tile(money(s.spent), "spent")
                        tile(s.averagePrice.map(money) ?? "—", "per ticket")
                    }

                    section("Records")
                    HStack(spacing: 14) {
                        tile("\(s.longestStreak)", s.longestStreak == 1 ? "week streak, best" : "weeks in a row, best")
                        tile("\(s.currentStreak)", "weeks in a row, now")
                    }
                    if let m = s.busiestMonth { row("Busiest month", "\(m.label) · \(m.count)") }
                    if s.busiestWeek > 1 { row("Most in one week", "\(s.busiestWeek)") }
                    if let f = s.first { row("First ticket", f.formatted(.dateTime.month(.wide).day().year())) }

                    if !s.kinds.isEmpty {
                        section("What you go to")
                        Chart(s.kinds) { k in
                            BarMark(x: .value("Nights", k.visits), y: .value("Kind", label(k.kind)))
                                .foregroundStyle(Theme.accent)
                                .annotation(position: .trailing) { Text("\(k.visits)").font(Theme.mono(12)).foregroundStyle(Theme.muted) }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: CGFloat(s.kinds.count) * 44)
                        .padding(16).glass()
                        ForEach(s.kinds) { k in if k.spent > 0 { row("Spent on \(label(k.kind).lowercased())", money(k.spent)) } }
                        if let t = s.topTeam { row("Team you see most", "\(t.0) · \(t.1)") }
                        if let a = s.topArtist { row("Artist you see most", "\(a.0) · \(a.1)") }
                        if let m = s.mostSeen { row("Seen most", "\(m.0) · \(m.1)×") }
                    }

                    section("Habits")
                    HStack(spacing: 14) {
                        tile(s.favoriteDay ?? "—", "favorite day")
                        tile(s.usualTime ?? "—", "usually")
                    }
                    HStack(spacing: 14) {
                        tile(s.hoursWatched > 0 ? "\(s.hoursWatched)h" : "—", "of film watched")
                        tile(s.favoriteRow.map { "Row \($0.0)" } ?? "—", "seat you pick most")
                    }

                    section("Places")
                    HStack(spacing: 14) {
                        tile("\(s.venues)", s.venues == 1 ? "venue" : "venues")
                        tile("\(s.newVenuesThisYear)", "new in \(String(s.year))")
                    }
                    if let v = s.favoriteVenue { row("Favorite venue", "\(v.0) · \(v.1)") }
                    if let far = farthest { row("Farthest trip", "\(far.0) · \(far.1)") }
                    if !pins.isEmpty {
                        Map {
                            ForEach(pins) { p in Marker(p.name, systemImage: "ticket", coordinate: p.coordinate).tint(Theme.accent) }
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .environment(\.colorScheme, .dark)
                    }

                    section("\(String(s.year)) by month")
                    Chart(s.byMonth) { m in
                        BarMark(x: .value("Month", Calendar.current.shortMonthSymbols[m.month - 1]), y: .value("Nights", m.count))
                            .foregroundStyle(Theme.cream)
                    }
                    .frame(height: 180)
                    .padding(16).glass()
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Stats")
            .task(id: s.venueNames) { pins = await VenuePin.locate(s.venueNames) }
        }
    }

    /// The venue farthest from the one you go to most.
    private var farthest: (String, String)? {
        let s = Stats(passes)
        guard let homeName = s.favoriteVenue?.0, let home = pins.first(where: { $0.name == homeName }) else { return nil }
        let h = CLLocation(latitude: home.coordinate.latitude, longitude: home.coordinate.longitude)
        guard let far = pins.max(by: { a, b in
            CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude).distance(from: h) <
            CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude).distance(from: h) }) else { return nil }
        let meters = CLLocation(latitude: far.coordinate.latitude, longitude: far.coordinate.longitude).distance(from: h)
        guard meters > 1000 else { return nil }
        let text = Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
        return (far.name, text)
    }

    private func label(_ k: EventKind) -> String { k == .movie ? "Films" : k == .sports ? "Games" : "Concerts" }
    private func money(_ v: Double) -> String { v.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0))) }

    private func section(_ t: String) -> some View {
        Text(t).font(Theme.serif(28)).foregroundStyle(Theme.ink).padding(.top, 12)
    }

    private func tile(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(.system(size: 28, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.caption).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).glass()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.sans(15)).foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            Text(value).font(Theme.sans(15, .medium)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).glass()
    }
}

/// A venue on the map. Found once by name with Apple Maps search and remembered.
struct VenuePin: Identifiable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    var id: String { name }

    static func locate(_ names: [String]) async -> [VenuePin] {
        var cache = Store.defaults.dictionary(forKey: "venueCoords") as? [String: [Double]] ?? [:]
        var out: [VenuePin] = []
        for n in names {
            if let c = cache[n], c.count == 2 {
                if c[0] != 0 || c[1] != 0 { out.append(VenuePin(name: n, coordinate: .init(latitude: c[0], longitude: c[1]))) }
                continue
            }
            let req = MKLocalSearch.Request(); req.naturalLanguageQuery = n
            if let item = try? await MKLocalSearch(request: req).start().mapItems.first {
                let c = item.placemark.coordinate
                cache[n] = [c.latitude, c.longitude]
                out.append(VenuePin(name: n, coordinate: c))
            } else {
                cache[n] = [0, 0]   // not found; don't ask again
            }
        }
        Store.defaults.set(cache, forKey: "venueCoords")
        return out
    }
}

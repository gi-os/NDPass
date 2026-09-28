import SwiftUI
import SwiftData
import Charts

struct CalendarView: View {
    @Query private var passes: [Pass]
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var picked: Date?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.title3.bold())
                        Spacer()
                        Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal)
                    grid
                    if let picked {
                        ForEach(dayPasses(picked), id: \.id) { p in TicketCard(passes: [p]).padding(.horizontal) }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.bg)
            .navigationTitle("Calendar")
        }
    }

    private func dayPasses(_ d: Date) -> [Pass] {
        passes.filter { p in PassTimes.day(p.date).map { cal.isDate($0, inSameDayAs: d) } ?? false }.sorted { $0.sortDate < $1.sortDate }
    }

    private var grid: some View {
        let first = cal.component(.weekday, from: month) - cal.firstWeekday
        let lead = (first + 7) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let cols = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<(lead + count), id: \.self) { i in
                if i < lead { Color.clear.frame(height: 54) } else {
                    let day = cal.date(byAdding: .day, value: i - lead, to: month)!
                    let ps = dayPasses(day)
                    Button { picked = day } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                if let p = ps.first { PassArt(pass: p).opacity(0.55) }
                                Text("\(i - lead + 1)").font(.subheadline.bold())
                            }
                            .frame(width: 40, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(cal.isDateInToday(day) ? Theme.cream : .clear, lineWidth: 1.5))
                            Circle().fill(ps.isEmpty ? .clear : Theme.orange).frame(width: 5, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct MonthCount: Identifiable { let month: Int; let count: Int; var id: Int { month } }

struct StatsView: View {
    @Query private var passes: [Pass]

    private func amount(_ s: String) -> Double { Double(s.filter { "0123456789.".contains($0) }) ?? 0 }

    var body: some View {
        let spent: Double = passes.reduce(0.0) { $0 + amount($1.price) }
        let venues = Dictionary(grouping: passes.filter { !$0.venue.isEmpty }, by: \.venue).mapValues(\.count)
        let fav = venues.max { $0.value < $1.value }
        let year = Calendar.current.component(.year, from: Date())
        let byMonth: [MonthCount] = (1...12).map { m in MonthCount(month: m, count: passes.filter { $0.date.hasPrefix(String(format: "%04d-%02d", year, m)) }.count) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        stat("\(passes.count)", "stubs")
                        stat(String(format: "$%.0f", spent), "spent")
                    }
                    stat(fav?.key ?? "—", fav.map { "favorite venue · \($0.value) visits" } ?? "favorite venue")
                    VStack(alignment: .leading) {
                        Text("\(String(year)) by month").font(.headline)
                        Chart(byMonth) { m in
                            BarMark(x: .value("Month", Calendar.current.shortMonthSymbols[m.month - 1]), y: .value("Tickets", m.count))
                                .foregroundStyle(Theme.cream)
                        }
                        .frame(height: 180)
                    }
                    .padding(16).glass()
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("Stats")
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(.system(size: 28, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.caption).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).glass()
    }
}

struct SettingsView: View {
    @State private var anthropic = Keys.get(.anthropic) ?? ""
    @State private var tmdb = Keys.get(.tmdb) ?? ""
    @State private var saved = false
    @State private var maps = Maps.preferred

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $anthropic).autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("Anthropic key") } footer: { Text("Claude Haiku reads your stubs. Without a key you type the fields yourself.") }
                Section {
                    SecureField("TMDb API key", text: $tmdb).autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("TMDb key (optional)") } footer: { Text("Posters and film search.") }
                Section {
                    Picker("Directions in", selection: $maps) {
                        ForEach(Maps.App.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } footer: { Text(Maps.googleInstalled ? "Tapping a venue opens directions here." : "Google Maps isn't installed, so it opens in the browser.") }
                Section {
                    Button(saved ? "Saved" : "Save keys") {
                        Keys.set(.anthropic, anthropic); Keys.set(.tmdb, tmdb); saved = true
                    }
                }
                Section { Text("Keys are stored in the iOS Keychain on this phone.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Settings")
            .onChange(of: anthropic) { _, _ in saved = false }
            .onChange(of: tmdb) { _, _ in saved = false }
            .onChange(of: maps) { _, v in Maps.preferred = v }
        }
    }
}

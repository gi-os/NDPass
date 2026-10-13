import SwiftUI
import SwiftData
import Charts

struct CalendarView: View {
    @Query private var passes: [Pass]
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var picked: Date?

    private var cal: Calendar { Calendar.current }

    /// Showings by day, worked out once per redraw.
    private var byDay: [Date: [[Pass]]] {
        var out: [Date: [[Pass]]] = [:]
        for g in Showings.groups(passes, archived: nil) {
            guard let d = PassTimes.day(g[0].date) else { continue }
            out[cal.startOfDay(for: d), default: []].append(g)
        }
        return out.mapValues { $0.sorted { $0[0].sortDate < $1[0].sortDate } }
    }

    var body: some View {
        let days = byDay
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.title3.bold())
                        Spacer()
                        Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .accessibilityLabel("Next month")
                    }
                    .padding(.horizontal)
                    weekdays
                    grid(days)
                    if let picked {
                        let gs = days[cal.startOfDay(for: picked)] ?? []
                        if gs.isEmpty {
                            Text("Nothing on \(picked.formatted(.dateTime.weekday(.wide).month(.wide).day())).").font(Theme.sans(14)).foregroundStyle(Theme.muted)
                        }
                        ForEach(gs, id: \.first!.group) { g in
                            NavigationLink(value: g[0].group) { TicketCard(passes: g) }.buttonStyle(.plain).padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Calendar")
            .navigationDestination(for: UUID.self) { DetailView(group: $0) }
        }
    }

    private func shift(_ n: Int) {
        month = cal.date(byAdding: .month, value: n, to: month) ?? month
        picked = nil
    }

    private var weekdays: some View {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let order = (0..<7).map { symbols[($0 + cal.firstWeekday - 1) % 7] }
        return HStack(spacing: 0) {
            ForEach(Array(order.enumerated()), id: \.offset) { _, d in
                Text(d).font(Theme.sans(11, .medium)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func grid(_ days: [Date: [[Pass]]]) -> some View {
        let first = cal.component(.weekday, from: month) - cal.firstWeekday
        let lead = (first + 7) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let cols = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<(lead + count), id: \.self) { i in
                if i < lead { Color.clear.frame(height: 54) } else {
                    let day = cal.date(byAdding: .day, value: i - lead, to: month) ?? month
                    let gs = days[cal.startOfDay(for: day)] ?? []
                    let isPicked = picked.map { cal.isDate($0, inSameDayAs: day) } ?? false
                    Button { picked = day } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                if let p = gs.first?.first { PassArt(pass: p).opacity(0.55) }
                                Text("\(i - lead + 1)").font(.subheadline.bold())
                            }
                            .frame(width: 40, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isPicked ? Theme.accent : (cal.isDateInToday(day) ? Theme.cream : .clear), lineWidth: 1.5))
                            Circle().fill(gs.isEmpty ? .clear : Theme.orange).frame(width: 5, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.formatted(.dateTime.month(.wide).day()) + (gs.isEmpty ? "" : ", \(gs.count) \(gs.count == 1 ? "ticket" : "tickets")"))
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SettingsView: View {
    @Environment(\.scenePhase) private var phase
    @Query private var passes: [Pass]
    @State private var anthropic = Keys.get(.anthropic) ?? ""
    @State private var tmdb = Keys.get(.tmdb) ?? ""
    @State private var sportsdb = Keys.get(.sportsdb) ?? ""
    @State private var maps = Maps.preferred
    @State private var reader = ReaderChoice.current
    @State private var askConsent = false
    @State private var calendarOn = CalendarSync.enabled && CalendarSync.authorized
    @State private var calendarID = CalendarSync.calendarID ?? ""
    @State private var calendars: [CalendarChoice] = []
    @State private var calendarDenied = false
    @State private var removed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Read tickets", selection: $reader) {
                        ForEach(ReaderChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text(reader == .onDevice
                         ? (OnDeviceReader.engine == .appleIntelligence ? "Read by Apple Intelligence on this iPhone. The photo never leaves your phone." : "Read on this iPhone from the ticket's text. The photo never leaves your phone. Turn on Apple Intelligence for better results, or use Claude.")
                         : "Sends the ticket photo to Anthropic's Claude API with your Anthropic key. Most accurate on worn or crumpled stubs.")
                }
                Section {
                    SecureField("sk-ant-…", text: $anthropic).autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("Anthropic key (optional)") } footer: { Text("Only used when Read tickets is set to Claude.") }
                Section {
                    SecureField("TMDb API key", text: $tmdb).autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("TMDb key (optional)") } footer: { Text("Posters and film details: the film's title is sent to TMDB to find them.") }
                Section {
                    SecureField("TheSportsDB API key", text: $sportsdb).autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("TheSportsDB key (optional)") } footer: { Text("Games get their teams' colors without a key. A key adds team crests; team names are sent to TheSportsDB to find them.") }

                Section {
                    Toggle("Add tickets to my calendar", isOn: $calendarOn)
                    if calendarOn {
                        Picker("Calendar", selection: $calendarID) {
                            Text("Default" + (CalendarSync.defaultCalendarName().map { " (\($0))" } ?? "")).tag("")
                            ForEach(calendars, id: \.id) { c in Text(c.title).tag(c.id) }
                        }
                    }
                    if CalendarSync.madeAny && !removed {
                        Button("Remove the events NDPass added", role: .destructive) {
                            CalendarSync.removeAll { removed = true }
                        }
                    }
                } header: { Text("Calendar") } footer: {
                    Text(calendarDenied
                         ? "NDPass isn't allowed to use your calendar. Turn on Full Access for NDPass in Settings > Privacy & Security > Calendars."
                         : "Every upcoming ticket gets an event, unless your calendar already has one for it. NDPass keeps its events up to date when you edit a ticket, and won't add back one you delete.")
                }

                Section {
                    SupportSection()
                } header: { Text("Support NDPass") } footer: {
                    Text("NDPass is free, with nothing locked. Gold and Gold Plus are one-time purchases that support it; they add an app icon and a thank-you, nothing else.")
                }

                Section {
                    Picker("Directions in", selection: $maps) {
                        ForEach(Maps.App.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } footer: { Text(Maps.googleInstalled ? "Tapping a venue opens directions here." : "Google Maps isn't installed, so it opens in the browser.") }
                Section { Text("Keys are kept in the iOS Keychain on this phone and saved as you type.").font(.footnote).foregroundStyle(.secondary) }
                Section("About") {
                    Link("Privacy policy", destination: URL(string: "https://gi-os.github.io/NDPass/privacy.html")!)
                    Link("Support", destination: URL(string: "https://gi-os.github.io/NDPass/")!)
                    Link(destination: URL(string: "https://www.themoviedb.org")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Film data and posters from TMDB").foregroundStyle(Theme.ink)
                            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Link(destination: URL(string: "https://www.thesportsdb.com")!) {
                        Text("Team crests from TheSportsDB").foregroundStyle(Theme.ink)
                    }
                    Link(destination: URL(string: "https://www.deezer.com")!) {
                        Text("Artist photos from Deezer").foregroundStyle(Theme.ink)
                    }
                    Text("NDPass \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: anthropic) { _, v in Keys.set(.anthropic, v) }
            .onChange(of: tmdb) { _, v in Keys.set(.tmdb, v) }
            .onChange(of: sportsdb) { _, v in Keys.set(.sportsdb, v) }
            .onChange(of: maps) { _, v in Maps.preferred = v }
            .onChange(of: reader) { _, v in
                if v == .claude && !AIConsent.granted { askConsent = true } else { ReaderChoice.current = v }
            }
            .onChange(of: calendarOn) { _, on in Task { await setCalendar(on) } }
            .onChange(of: calendarID) { _, id in
                CalendarSync.calendarID = id.isEmpty ? nil : id
                CalendarSync.sync(passes)
            }
            .onAppear(perform: loadCalendars)
            .onChange(of: phase) { _, p in if p == .active { loadCalendars() } }
            .sheet(isPresented: $askConsent, onDismiss: {
                // Swiped away without answering: stay with reading on this iPhone.
                if !AIConsent.granted { reader = .onDevice; ReaderChoice.current = .onDevice }
            }) {
                AIConsentSheet { ok in
                    AIConsent.granted = ok
                    reader = ok ? .claude : .onDevice
                    ReaderChoice.current = reader
                    askConsent = false
                }
            }
        }
    }

    private func loadCalendars() {
        calendarDenied = CalendarSync.denied
        if calendarDenied { calendarOn = false }
        calendars = CalendarSync.writableCalendars().map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title) }
        if !calendarID.isEmpty, !calendars.contains(where: { $0.id == calendarID }) { calendarID = "" }
    }

    private func setCalendar(_ on: Bool) async {
        guard on else { CalendarSync.enabled = false; return }
        if !CalendarSync.authorized {
            let ok = await CalendarSync.requestAccess()
            if !ok { calendarOn = false; calendarDenied = true; return }
        }
        CalendarSync.enabled = true
        removed = false
        loadCalendars()
        CalendarSync.sync(passes)
    }
}

struct CalendarChoice: Identifiable, Hashable { let id: String; let title: String }

import SwiftUI
import SwiftData

/// Tickets shared from other apps land in the App Group inbox; they're read and filed
/// whenever NDPass comes to the front.
extension RootView {
    @MainActor
    func drainInbox() async {
        guard !Demo.active else { return }
        var added = 0
        for (item, img, dir) in Inbox.pending() {
            let p: Pass?
            if let d = img, let image = UIImage(data: d) {
                p = await importer.add(image, sourceURL: item.url, prefetchedText: item.text, into: ctx)
            } else {
                p = await importer.add(text: item.text ?? "", image: nil, sourceURL: item.url, into: ctx)
            }
            Inbox.remove(dir)
            if p != nil { added += 1 }
        }
        if added > 0 { sharedAdded = added }
    }
}

struct RootView: View {
    @StateObject private var importer = Importer()
    @Environment(\.modelContext) private var ctx
    @State private var imported = 0
    @Query private var passes: [Pass]

    /// "Tonight" when something is on this evening, "Today" earlier in the day, "Up Next"
    /// when the next one is later.
    private var firstTabTitle: String {
        guard let next = Showings.groups(passes, archived: false).first?.first, let s = next.start, Calendar.current.isDateInToday(s) else { return "Up Next" }
        return Calendar.current.component(.hour, from: s) >= 17 ? "Tonight" : "Today"
    }
    @State private var openFailed = Store.openFailed
    @State private var keysCameToo = false

    /// Everything that follows the tickets (reminders, calendar events, Live Activities),
    /// redone together whenever a showing changes.
    private var syncKey: String {
        passes.map { "\($0.group)\($0.date)\($0.time)\($0.title)\($0.venue)\($0.seat)\($0.kindRaw)\($0.arrival)\($0.gate)" }.sorted().joined(separator: "|")
    }

    private func syncAll() async {
        guard !Demo.active else { return }
        let live = passes.filter { !$0.isDeleted }
        Reminders.sync(live)
        CalendarSync.sync(live)
        await LiveCountdown.refresh(live)
    }
    @State private var sharedAdded = 0
    @State private var tab = 0
    @State private var doorGroup: UUID?
    @Environment(\.scenePhase) private var phase

    private func handle(_ url: URL) {
        guard let link = CountdownLink(url) else { return }
        let g = Showings.sortSeats(passes.filter { $0.group == link.group })
        guard let p = g.first else { return }
        switch link.action {
        case .ticket: tab = 0
        case .door: tab = 0; doorGroup = link.group
        case .seller: Seller.open(p)
        case .directions: Maps.open(p.venue)
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(firstTabTitle, systemImage: "ticket", value: 0) { TonightView() }
            Tab("Collection", systemImage: "square.grid.2x2", value: 1) { CollectionView() }
            Tab("Calendar", systemImage: "calendar", value: 2) { CalendarView() }
            Tab("Stats", systemImage: "chart.bar", value: 3) { StatsView() }
            Tab("Settings", systemImage: "gearshape", value: 4) { SettingsView() }
        }
        .environmentObject(importer)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task { Supporter.shared.start() }
        .onAppear {
            guard !Demo.active else { return }
            let hadKeys = Keys.get(.anthropic) != nil || Keys.get(.tmdb) != nil
            imported = ExpoImport.runIfNeeded(ctx)
            keysCameToo = !hadKeys && (Keys.get(.anthropic) != nil || Keys.get(.tmdb) != nil)
        }
        .task {
            // Once: times saved as 24-hour get AM/PM; titles and venues saved in all caps
            // or all lowercase get Title Case.
            guard !Demo.active, !Store.defaults.bool(forKey: "ampm") else { return }
            for p in (try? ctx.fetch(FetchDescriptor<Pass>())) ?? [] {
                if p.kind == .transit { continue }
                if let t = PassTimes.normalizeTime(p.time), t != p.time { p.time = t }
                let t = PassTimes.display(p.title); if t != p.title { p.title = t }
                let v = PassTimes.display(p.venue); if v != p.venue { p.venue = v }
            }
            try? ctx.save()
            Store.defaults.set(true, forKey: "ampm")
        }
        .task {
            // Art for games, concerts and shows that have none yet (read offline, or before
            // the artist was found). Never redraws art you picked and never renames a ticket.
            guard !Demo.active else { return }
            let todo = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.kind != .movie && $0.art == nil }
            for p in todo where !p.isDeleted { await EventArt.decorate(p, rename: false) }
            // With a TheSportsDB key, games drawn without crests get them, once.
            if Keys.get(.sportsdb) != nil {
                let d = Store.defaults
                var done = Set(d.stringArray(forKey: "crests") ?? [])
                let picked = Set(d.stringArray(forKey: EventArt.pickedKey) ?? [])
                let games = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.kind == .sports && !done.contains($0.id.uuidString) && !picked.contains($0.group.uuidString) }
                for p in games where !p.isDeleted {
                    await EventArt.decorate(p, rename: false)
                    done.insert(p.id.uuidString)
                }
                d.set(Array(done), forKey: "crests")
            }
            try? ctx.save()
        }
        .task {
            guard !Demo.active, let key = Keys.get(.tmdb) else { return }
            let checked = Set(UserDefaults.standard.stringArray(forKey: "logoChecked") ?? [])
            let todo = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.tmdbID != nil && $0.logoPath == nil && !checked.contains($0.id.uuidString) }
            var done = checked
            for p in todo where !p.isDeleted { await TMDb.art(for: p, key: key); done.insert(p.id.uuidString) }
            try? ctx.save()
            UserDefaults.standard.set(Array(done), forKey: "logoChecked")
        }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await drainInbox(); await syncAll() } }
        }
        .task(id: syncKey) {
            // A moment's pause so a burst of edits (a merge, a batch import) syncs once.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await syncAll()
        }
        .onOpenURL { handle($0) }
        .fullScreenCover(item: Binding(get: { doorGroup.map(DoorID.init) }, set: { doorGroup = $0?.id })) { d in
            DoorView(passes: Showings.sortSeats(passes.filter { $0.group == d.id }))
        }
        .alert(sharedAdded == 1 ? "Added a shared ticket" : "Added \(sharedAdded) shared tickets", isPresented: Binding(get: { sharedAdded > 0 }, set: { if !$0 { sharedAdded = 0 } })) {
            Button("OK") {}
        }
        .alert("Brought over \(imported) tickets from the old NDPass", isPresented: Binding(get: { imported > 0 }, set: { if !$0 { imported = 0 } })) {
            Button("OK") {}
        } message: { if keysCameToo { Text("Your keys came across too.") } }
        .alert("Couldn't open your tickets", isPresented: $openFailed) {
            Button("OK") {}
        } message: { Text("Your tickets are safe. Close NDPass and open it again; if this keeps happening, restart your iPhone.") }
    }
}

private struct DoorID: Identifiable { let id: UUID }

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

    /// "Tonight" when something is on today; "Up Next" when the next one is later.
    private var firstTabTitle: String {
        let next = passes.filter { !$0.isArchived }.min { $0.sortDate < $1.sortDate }
        return next.map { Calendar.current.isDateInToday($0.sortDate) } == true ? "Tonight" : "Up Next"
    }
    @State private var sharedAdded = 0
    @State private var tab = 0
    @State private var doorGroup: UUID?
    @Environment(\.scenePhase) private var phase

    private func handle(_ url: URL) {
        guard let link = CountdownLink(url) else { return }
        let g = passes.filter { $0.group == link.group }.sorted { $0.seat < $1.seat }
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
        .onAppear {
            guard !Demo.active else { return }
            Reminders.requestAccess()
            imported = ExpoImport.runIfNeeded(ctx)
        }
        .task {
            // Games and concerts saved before crests and album art: draw them again, once
            // (and again for games after a TheSportsDB key is added).
            guard !Demo.active else { return }
            let tag = Keys.get(.sportsdb) == nil ? "art2" : "art2+sdb"
            let d = Store.defaults
            var done = Set(d.stringArray(forKey: tag) ?? [])
            let events = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.kind != .movie && !done.contains($0.id.uuidString) }
            for p in events {
                if let art = await EventArt.art(for: p.kind, title: p.title, context: p.venue) { p.art = art }
                done.insert(p.id.uuidString)
            }
            try? ctx.save()
            d.set(Array(done), forKey: tag)
        }
        .task {
            guard !Demo.active, let key = Keys.get(.tmdb) else { return }
            let checked = Set(UserDefaults.standard.stringArray(forKey: "logoChecked") ?? [])
            let todo = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.tmdbID != nil && $0.logoPath == nil && !checked.contains($0.id.uuidString) }
            var done = checked
            for p in todo { await TMDb.art(for: p, key: key); done.insert(p.id.uuidString) }
            try? ctx.save()
            UserDefaults.standard.set(Array(done), forKey: "logoChecked")
        }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await drainInbox(); await LiveCountdown.refresh(passes) } }
        }
        .onChange(of: passes.map { "\($0.group)\($0.date)\($0.time)" }) { _, _ in Task { await LiveCountdown.refresh(passes) } }
        .onOpenURL { handle($0) }
        .fullScreenCover(item: Binding(get: { doorGroup.map(DoorID.init) }, set: { doorGroup = $0?.id })) { d in
            DoorView(passes: passes.filter { $0.group == d.id }.sorted { $0.seat < $1.seat })
        }
        .alert(sharedAdded == 1 ? "Added a shared ticket" : "Added \(sharedAdded) shared tickets", isPresented: Binding(get: { sharedAdded > 0 }, set: { if !$0 { sharedAdded = 0 } })) {
            Button("OK") {}
        }
        .alert("Brought over \(imported) tickets from the old NDPass", isPresented: Binding(get: { imported > 0 }, set: { if !$0 { imported = 0 } })) {
            Button("OK") {}
        } message: { Text("Your keys came across too.") }
    }
}

private struct DoorID: Identifiable { let id: UUID }

import SwiftUI
import SwiftData

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

    var body: some View {
        TabView {
            Tab(firstTabTitle, systemImage: "ticket") { TonightView() }
            Tab("Collection", systemImage: "square.grid.2x2") { CollectionView() }
            Tab("Calendar", systemImage: "calendar") { CalendarView() }
            Tab("Stats", systemImage: "chart.bar") { StatsView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
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
            guard !Demo.active, let key = Keys.get(.tmdb) else { return }
            let checked = Set(UserDefaults.standard.stringArray(forKey: "logoChecked") ?? [])
            let todo = ((try? ctx.fetch(FetchDescriptor<Pass>())) ?? []).filter { $0.tmdbID != nil && $0.logoPath == nil && !checked.contains($0.id.uuidString) }
            var done = checked
            for p in todo { await TMDb.art(for: p, key: key); done.insert(p.id.uuidString) }
            try? ctx.save()
            UserDefaults.standard.set(Array(done), forKey: "logoChecked")
        }
        .alert("Brought over \(imported) tickets from the old NDPass", isPresented: Binding(get: { imported > 0 }, set: { if !$0 { imported = 0 } })) {
            Button("OK") {}
        } message: { Text("Your keys came across too.") }
    }
}

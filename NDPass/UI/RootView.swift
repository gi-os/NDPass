import SwiftUI
import SwiftData

struct RootView: View {
    @StateObject private var importer = Importer()
    @Environment(\.modelContext) private var ctx
    @State private var imported = 0

    var body: some View {
        TabView {
            Tab("Tonight", systemImage: "ticket") { TonightView() }
            Tab("Collection", systemImage: "square.grid.2x2") { CollectionView() }
            Tab("Calendar", systemImage: "calendar") { CalendarView() }
            Tab("Stats", systemImage: "chart.bar") { StatsView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .environmentObject(importer)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            Reminders.requestAccess()
            imported = ExpoImport.runIfNeeded(ctx)
        }
        .alert("Brought over \(imported) tickets from the old NDPass", isPresented: Binding(get: { imported > 0 }, set: { if !$0 { imported = 0 } })) {
            Button("OK") {}
        } message: { Text("Your keys came across too.") }
    }
}

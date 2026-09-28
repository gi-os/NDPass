import SwiftUI
import SwiftData

struct RootView: View {
    @StateObject private var importer = Importer()

    var body: some View {
        TabView {
            Tab("Tickets", systemImage: "ticket") { TicketsView().environmentObject(importer) }
            Tab("Calendar", systemImage: "calendar") { CalendarView() }
            Tab("Stats", systemImage: "chart.bar") { StatsView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .tint(Theme.cream)
        .preferredColorScheme(.dark)
        .onAppear { Reminders.requestAccess() }
    }
}

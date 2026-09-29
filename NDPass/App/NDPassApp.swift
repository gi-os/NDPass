import SwiftUI
import SwiftData

@main
struct NDPassApp: App {
    @State private var container: ModelContainer
    @State private var stamp = Store.stamp
    @Environment(\.scenePhase) private var phase

    init() {
        Theme.applyNavigationFonts()
        Store.migrate()
        _container = State(initialValue: Demo.active ? Demo.container() : Store.container())
    }

    var body: some Scene {
        WindowGroup {
            RootView().modelContainer(container).id(ObjectIdentifier(container))
        }
        .onChange(of: phase) { _, p in
            // The share sheet saved into the same database: reopen it so the new ticket shows.
            guard p == .active, !Demo.active, Store.stamp != stamp else { return }
            stamp = Store.stamp
            container = Store.container()
        }
    }
}

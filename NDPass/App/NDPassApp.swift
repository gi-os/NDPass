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
        let c = Demo.active ? Demo.container() : Store.container()
        if !Demo.active { _ = Store.mergeOld(into: c) }
        _container = State(initialValue: c)
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

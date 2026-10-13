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
            // The database lives in the shared App Group: give any save in flight a moment to
            // finish before iOS suspends the app, or iOS may end it for holding the file.
            if p == .background {
                var task = UIBackgroundTaskIdentifier.invalid
                task = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(task) }
                try? container.mainContext.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { UIApplication.shared.endBackgroundTask(task) }
            }
            // The share sheet saved into the same database: reopen it so the new ticket shows.
            guard p == .active, !Demo.active, Store.stamp != stamp || Store.openFailed else { return }
            stamp = Store.stamp
            container = Store.container()
        }
    }
}

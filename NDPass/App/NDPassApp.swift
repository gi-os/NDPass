import SwiftUI
import SwiftData

@main
struct NDPassApp: App {
    init() { Theme.applyNavigationFonts() }

    var body: some Scene {
        WindowGroup {
            if Demo.active { RootView().modelContainer(Demo.container()) }
            else { RootView().modelContainer(for: Pass.self) }
        }
    }
}

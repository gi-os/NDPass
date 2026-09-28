import SwiftUI
import SwiftData

@main
struct NDPassApp: App {
    init() { Theme.applyNavigationFonts() }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: Pass.self)
    }
}

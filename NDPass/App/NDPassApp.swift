import SwiftUI
import SwiftData

@main
struct NDPassApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: Pass.self)
    }
}

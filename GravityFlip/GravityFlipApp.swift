import SwiftUI

@main
struct GravityFlipApp: App {
    init() {
        AdManager.shared.initialize()
        // Touch StoreManager singleton so entitlement check starts before first screen renders.
        _ = StoreManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

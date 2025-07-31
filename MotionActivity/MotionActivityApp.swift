import SwiftUI

@main
struct MotionActivityApp: App {
    @State private var rootStore = RootStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: rootStore)
        }
    }
}
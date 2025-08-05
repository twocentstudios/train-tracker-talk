import SwiftUI

@main struct GroundTruthLoggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(store: appDelegate.rootStore)
        }
    }
}

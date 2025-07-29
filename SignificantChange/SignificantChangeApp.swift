import SwiftUI

@main
struct SignificantChangeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(store: appDelegate.rootStore)
        }
    }
}

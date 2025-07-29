import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    let rootStore: RootStore = .init(state: .init())

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        rootStore.startMonitoring()
        return true
    }
}

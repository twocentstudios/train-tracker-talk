import SharingGRDB
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    let rootStore: RootStore = .init()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
        return true
    }
}

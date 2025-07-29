import CoreLocation
import Observation
import SharingGRDB

@MainActor @Observable final class RootStore: NSObject {
    struct State: Equatable {}

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isMonitoring: Bool
    private var hasHandledFirstLocationFromColdLaunch = false

    var state: State

    init(state: State) {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        isMonitoring = false
        self.state = state

        super.init()

        manager.delegate = self
    }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            return
        }
    }

    func startMonitoring() {
        guard manager.authorizationStatus == .authorizedAlways else {
            print("Location Services unauthorized")
            return
        }

        guard !isMonitoring else { return }
        isMonitoring = true

        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringSignificantLocationChanges()
        manager.pausesLocationUpdatesAutomatically = false
    }
}

// Always called on thread on which `CLLocationManager` was initialized
extension RootStore: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        @Dependency(\.uuid) var uuid
        withErrorReporting {
            try database.write { db in
                for clLocation in locations {
                    let isFromColdLaunch = !hasHandledFirstLocationFromColdLaunch
                    let location = Location(from: clLocation, id: uuid(), isFromColdLaunch: isFromColdLaunch)
                    try Location.insert { location }.execute(db)

                    if !hasHandledFirstLocationFromColdLaunch {
                        hasHandledFirstLocationFromColdLaunch = true
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // Start after initial authorization passes
        startMonitoring()
    }
}

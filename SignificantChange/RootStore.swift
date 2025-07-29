import CoreLocation
import Observation

@MainActor @Observable final class RootStore: NSObject {
    struct State: Equatable {}

    @ObservationIgnored private let manager: CLLocationManager

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isMonitoring: Bool

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
        print(locations)
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

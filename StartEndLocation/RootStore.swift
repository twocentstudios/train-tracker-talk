import CoreLocation
import CoreMotion
import Observation
import SharingGRDB

@MainActor @Observable final class RootStore: NSObject {
    private enum LocationMonitoringState {
        case waitingForSignificantChange
        case collectingLiveUpdates(sessionID: UUID, startTime: Date)
    }

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private let activityManager: CMMotionActivityManager
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var motionAuthorizationStatus: CMAuthorizationStatus
    private(set) var isMotionAvailable: Bool
    private(set) var isMonitoringSignificantLocationChanges: Bool
    private var hasHandledFirstLocationFromColdLaunch = false
    private var locationMonitoringState: LocationMonitoringState = .waitingForSignificantChange
    private var sessionTask: Task<Void, Never>?
    private var lastSessionEndTime: Date?

    override init() {
        manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        authorizationStatus = manager.authorizationStatus
        isMonitoringSignificantLocationChanges = false

        activityManager = CMMotionActivityManager()
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        isMotionAvailable = CMMotionActivityManager.isActivityAvailable()

        super.init()

        manager.delegate = self
    }

    var isMotionAuthorized: Bool {
        motionAuthorizationStatus == .authorized
    }

    func requestLocationAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            return
        }
    }

    func requestMotionAuthorization() {
        guard isMotionAvailable, motionAuthorizationStatus != .authorized else { return }

        let startDate = Date().addingTimeInterval(-1)
        let endDate = Date()

        activityManager.queryActivityStarting(
            from: startDate,
            to: endDate,
            to: OperationQueue.main
        ) { [weak self] _, _ in
            self?.motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        }
    }

    func startMonitoring() {
        guard manager.authorizationStatus == .authorizedAlways, manager.accuracyAuthorization == .fullAccuracy else {
            print("Location Services unauthorized")
            return
        }

        guard !isMonitoringSignificantLocationChanges else { return }
        isMonitoringSignificantLocationChanges = true

        locationMonitoringState = .waitingForSignificantChange
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringSignificantLocationChanges()
        manager.pausesLocationUpdatesAutomatically = false
    }

    private func startLiveLocationUpdates(for sessionID: UUID) {
        guard sessionTask == nil else {
            assertionFailure("sessionTask is already active")
            return
        }

        @Dependency(\.date) var date
        let startTime = date()
        locationMonitoringState = .collectingLiveUpdates(sessionID: sessionID, startTime: startTime)
        lastSessionEndTime = nil

        manager.startUpdatingLocation()

        sessionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(180))
                self?.stopLiveLocationUpdates()
            } catch {}
        }
    }

    private func stopLiveLocationUpdates() {
        @Dependency(\.date) var date
        manager.stopUpdatingLocation()
        sessionTask?.cancel()
        sessionTask = nil
        lastSessionEndTime = date()
        locationMonitoringState = .waitingForSignificantChange
    }
}

// Always called on thread on which `CLLocationManager` was initialized
extension RootStore: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        @Dependency(\.uuid) var uuid
        @Dependency(\.date) var date

        // Assert if called within 10 seconds of session ending
        if let lastEndTime = lastSessionEndTime, date().timeIntervalSince(lastEndTime) < 10.0 {
            assertionFailure("didUpdateLocations called within 10 seconds of session ending - cannot determine if this is from significant location change or final locations from startUpdatingLocation")
        }

        switch locationMonitoringState {
        case .waitingForSignificantChange:
            // This is a significant location change - create new session
            let sessionID = uuid()
            let isFromColdLaunch = !hasHandledFirstLocationFromColdLaunch

            withErrorReporting {
                try database.write { db in
                    let session = Session(id: sessionID, date: date(), isFromColdLaunch: isFromColdLaunch)
                    try Session.insert { session }.execute(db)

                    for clLocation in locations {
                        let location = Location(from: clLocation, id: uuid(), sessionID: sessionID)
                        try Location.insert { location }.execute(db)
                    }
                }
            }

            if !hasHandledFirstLocationFromColdLaunch {
                hasHandledFirstLocationFromColdLaunch = true
            }

            // Start collecting live updates for 3 minutes
            startLiveLocationUpdates(for: sessionID)

        case let .collectingLiveUpdates(sessionID, _):
            // This is from live location updates - use current session
            withErrorReporting {
                try database.write { db in
                    for clLocation in locations {
                        let location = Location(from: clLocation, id: uuid(), sessionID: sessionID)
                        try Location.insert { location }.execute(db)
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

import CoreLocation
import CoreMotion
import GRDB
import Observation
import SharingGRDB

@MainActor @Observable final class RootStore: NSObject {
    private enum LocationMonitoringState {
        case waitingForSignificantChange
        case evaluatingSession(sessionID: UUID, startTime: Date, timeoutDuration: TimeInterval, speedCount: Int)
        case collectingLiveUpdates(sessionID: UUID, startTime: Date, speedCount: Int, lastHighSpeedTime: Date?)
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
    private var motionActivityTask: Task<Void, Never>?
    private var evaluationTimeoutTask: Task<Void, Never>?

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

        Task { @MainActor [weak self] in
            guard let self else { return }
            motionAuthorizationStatus = await activityManager.requestAuthorization()
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
        @Dependency(\.date) var date
        let startTime = date()
        locationMonitoringState = .collectingLiveUpdates(sessionID: sessionID, startTime: startTime, speedCount: 0, lastHighSpeedTime: nil)

        manager.startUpdatingLocation()
    }

    private func stopLiveLocationUpdates() {
        manager.stopUpdatingLocation()
        stopMotionActivityMonitoring()
        evaluationTimeoutTask?.cancel()
        evaluationTimeoutTask = nil
        locationMonitoringState = .waitingForSignificantChange
    }

    private func calculateTimeout(from activities: [CMMotionActivity]?) -> TimeInterval? {
        guard let activities else {
            return 60 // 1-minute timeout when activities is nil (timeout case)
        }

        let highConfidenceActivities = activities.filter { $0.confidence == .high }
        let automotiveCount = highConfidenceActivities.filter(\.automotive).count
        let walkingCount = highConfidenceActivities.filter(\.walking).count
        let cyclingCount = highConfidenceActivities.filter(\.cycling).count

        if automotiveCount > 0 {
            return 300 // 5 minutes
        } else if walkingCount > 0 || cyclingCount > 0 {
            return 60 // 1 minute
        } else {
            // Only stationary, no data, or no movement activities
            return nil
        }
    }

    private func startMotionActivityMonitoring(for sessionID: UUID) {
        guard isMotionAvailable, isMotionAuthorized else { return }

        motionActivityTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await activity in activityManager.activityUpdates() {
                let motionActivity = MotionActivity(from: activity, sessionID: sessionID)

                withErrorReporting {
                    try self.database.write { db in
                        try MotionActivity.insert { motionActivity }.execute(db)
                    }
                }

                // Check for stop condition: walking with high confidence
                if activity.walking, activity.confidence == .high {
                    handleSessionEnd()
                    break
                }
            }
        }
    }

    private func stopMotionActivityMonitoring() {
        motionActivityTask?.cancel()
        motionActivityTask = nil
    }

    private func handleSessionEnd() {
        @Dependency(\.date) var date

        switch locationMonitoringState {
        case let .evaluatingSession(sessionID, _, _, _),
             let .collectingLiveUpdates(sessionID, _, _, _):
            // Update session end date
            withErrorReporting {
                try database.write { db in
                    try Session.update {
                        $0.endDate = date()
                    }
                    .where { $0.id == sessionID }
                    .execute(db)
                }
            }
        case .waitingForSignificantChange:
            break
        }

        stopLiveLocationUpdates()
    }

    private func writeMotionActivityHistory(activities: [CMMotionActivity], for sessionID: UUID) {
        @Dependency(\.uuid) var uuid

        withErrorReporting {
            try database.write { db in
                for cmActivity in activities {
                    let motionActivity = MotionActivity(from: cmActivity, sessionID: sessionID)
                    try MotionActivity.insert { motionActivity }.execute(db)
                }
            }
        }
    }
}

// Always called on thread on which `CLLocationManager` was initialized
extension RootStore: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        @Dependency(\.uuid) var uuid
        @Dependency(\.date) var date

        switch locationMonitoringState {
        case .waitingForSignificantChange:
            // This is a significant location change - create new session
            let sessionID = uuid()
            let isFromColdLaunch = !hasHandledFirstLocationFromColdLaunch

            withErrorReporting {
                try database.write { db in
                    let session = Session(id: sessionID, startDate: date(), isFromColdLaunch: isFromColdLaunch)
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

            // Check motion activity history and transition to evaluating state
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Query historical motion activities
                let endDate = date()
                let startDate = endDate.addingTimeInterval(-1200) // 20 minutes

                do {
                    let activities = try await activityManager.activities(from: startDate, to: endDate, timeout: 5)

                    writeMotionActivityHistory(activities: activities ?? [], for: sessionID)

                    let timeout = calculateTimeout(from: activities)

                    if let timeout {
                        // Transition to evaluating state with timeout
                        locationMonitoringState = .evaluatingSession(
                            sessionID: sessionID,
                            startTime: date(),
                            timeoutDuration: timeout,
                            speedCount: 0
                        )

                        // Start location updates
                        manager.startUpdatingLocation()

                        // Start motion activity monitoring
                        startMotionActivityMonitoring(for: sessionID)

                        // Set timeout
                        evaluationTimeoutTask = Task { @MainActor [weak self] in
                            do {
                                try await Task.sleep(for: .seconds(timeout))
                                self?.handleSessionEnd()
                            } catch {}
                        }
                    } else {
                        // No timeout - close session immediately
                        withErrorReporting {
                            try self.database.write { db in
                                try Session.update {
                                    $0.endDate = date()
                                }
                                .where { $0.id == sessionID }
                                .execute(db)
                            }
                        }
                    }
                } catch {
                    // CoreMotion errors - close session immediately
                    print("CoreMotion query failed: \(error)")
                    withErrorReporting {
                        try self.database.write { db in
                            try Session.update {
                                $0.endDate = date()
                            }
                            .where { $0.id == sessionID }
                            .execute(db)
                        }
                    }
                }
            }

        case let .evaluatingSession(sessionID, startTime, timeoutDuration, speedCount):
            // Track locations and check for speed threshold
            var updatedSpeedCount = speedCount

            withErrorReporting {
                try database.write { db in
                    for clLocation in locations {
                        let location = Location(from: clLocation, id: uuid(), sessionID: sessionID)
                        try Location.insert { location }.execute(db)

                        // Check speed threshold
                        if clLocation.speed >= 6.0 {
                            updatedSpeedCount += 1
                        }
                    }
                }
            }

            // Check if we should transition to collecting state
            if updatedSpeedCount >= 3 {
                // Cancel timeout
                evaluationTimeoutTask?.cancel()
                evaluationTimeoutTask = nil

                // Update session to mark as on train
                withErrorReporting {
                    try database.write { db in
                        try Session.update {
                            $0.isOnTrain = true
                        }
                        .where { $0.id == sessionID }
                        .execute(db)
                    }
                }

                // Transition to collecting state
                let lastHighSpeed = locations.last { $0.speed >= 6.0 }?.timestamp
                locationMonitoringState = .collectingLiveUpdates(
                    sessionID: sessionID,
                    startTime: startTime,
                    speedCount: 0,
                    lastHighSpeedTime: lastHighSpeed
                )
            } else if updatedSpeedCount != speedCount {
                // Update state only if speed count changed
                locationMonitoringState = .evaluatingSession(
                    sessionID: sessionID,
                    startTime: startTime,
                    timeoutDuration: timeoutDuration,
                    speedCount: updatedSpeedCount
                )
            }

        case let .collectingLiveUpdates(sessionID, startTime, speedCount, lastHighSpeedTime):
            // Continue collecting and check for stop conditions
            var updatedLastHighSpeedTime = lastHighSpeedTime

            withErrorReporting {
                try database.write { db in
                    for clLocation in locations {
                        let location = Location(from: clLocation, id: uuid(), sessionID: sessionID)
                        try Location.insert { location }.execute(db)

                        // Update last high speed time
                        if clLocation.speed >= 6.0 {
                            updatedLastHighSpeedTime = clLocation.timestamp
                        }
                    }
                }
            }

            // Check 15-minute timeout condition
            if let lastHighSpeed = updatedLastHighSpeedTime,
               date().timeIntervalSince(lastHighSpeed) > 900
            {
                handleSessionEnd()
            } else if updatedLastHighSpeedTime != lastHighSpeedTime {
                // Update state only if last high speed time changed
                locationMonitoringState = .collectingLiveUpdates(
                    sessionID: sessionID,
                    startTime: startTime,
                    speedCount: speedCount,
                    lastHighSpeedTime: updatedLastHighSpeedTime
                )
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

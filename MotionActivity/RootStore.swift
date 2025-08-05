import CoreMotion
import Observation

@MainActor @Observable final class RootStore {
    private(set) var isMotionAvailable: Bool
    private(set) var liveActivities: [MotionActivity] = []
    private(set) var historicalActivities: [MotionActivity] = []
    private(set) var isUpdating = false
    private(set) var isLoadingHistorical = false
    private(set) var historicalError: String?
    private(set) var authorizationStatus: CMAuthorizationStatus
    private let activityManager = CMMotionActivityManager()

    init() {
        isMotionAvailable = CMMotionActivityManager.isActivityAvailable()
        authorizationStatus = CMMotionActivityManager.authorizationStatus()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    func startIfAuthorized() {
        guard isMotionAvailable, isAuthorized, !isUpdating else { return }
        isUpdating = true
        startLiveUpdates()
    }

    func requestMotionPermission() {
        guard isMotionAvailable, !isUpdating else { return }
        isUpdating = true
        startLiveUpdates()
    }

    func stopUpdates() {
        guard isUpdating else { return }
        activityManager.stopActivityUpdates()
        isUpdating = false
    }

    private func startLiveUpdates() {
        activityManager.startActivityUpdates(to: OperationQueue.main) { [weak self] cmActivity in
            guard let self, let cmActivity else { return }
            if authorizationStatus != .authorized {
                authorizationStatus = CMMotionActivityManager.authorizationStatus()
            }

            let newActivity = MotionActivity(from: cmActivity)

            if let existingIndex = liveActivities.firstIndex(where: { $0.startDate == newActivity.startDate }) {
                liveActivities[existingIndex] = newActivity
            } else {
                liveActivities.append(newActivity)
            }
        }
    }

    func fetchHistoricalActivities() {
        guard isMotionAvailable, isAuthorized, !isLoadingHistorical else { return }

        isLoadingHistorical = true
        historicalError = nil

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-30 * 24 * 60 * 60) // 30 days to get maximum available

        activityManager.queryActivityStarting(
            from: startDate,
            to: endDate,
            to: OperationQueue.main
        ) { [weak self] cmActivities, error in
            guard let self else { return }

            isLoadingHistorical = false

            if let error {
                historicalError = "Failed to load historical data: \(error.localizedDescription)"
            } else if let cmActivities {
                historicalActivities = cmActivities.map(MotionActivity.init)
            } else {
                historicalError = "No historical data available"
            }
        }
    }
}

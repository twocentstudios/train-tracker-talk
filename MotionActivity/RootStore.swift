import CoreMotion
import Observation

@MainActor @Observable final class RootStore {
    private(set) var isMotionAvailable: Bool
    private(set) var activities: [MotionActivity] = []
    private(set) var isUpdating = false
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

            if let existingIndex = activities.firstIndex(where: { $0.startDate == newActivity.startDate }) {
                activities[existingIndex] = newActivity
            } else {
                activities.append(newActivity)
            }
        }
    }
}

import CoreMotion
import Observation

@MainActor @Observable final class RootStore {
    private(set) var isMotionAvailable: Bool
    private(set) var activities: [MotionActivity] = []
    private let activityManager = CMMotionActivityManager()
    private let queue = OperationQueue()
    private var isUpdating = false

    init() {
        self.isMotionAvailable = CMMotionActivityManager.isActivityAvailable()
        queue.qualityOfService = .utility
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
        activityManager.startActivityUpdates(to: queue) { [weak self] cmActivity in
            guard let self, let cmActivity = cmActivity else { return }
            
            Task { @MainActor in
                let newActivity = MotionActivity(from: cmActivity)
                
                if let existingIndex = self.activities.firstIndex(where: { $0.startDate == newActivity.startDate }) {
                    self.activities[existingIndex] = newActivity
                } else {
                    self.activities.append(newActivity)
                }
            }
        }
    }
}
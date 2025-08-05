import CoreMotion
import Foundation

extension CMMotionActivityManager {
    /// According to docs, it's possible for this request to take several minutes to return.
    @MainActor func activities(
        from start: Date,
        to end: Date,
        timeout: TimeInterval
    ) async throws -> [CMMotionActivity]? {
        try await withThrowingTaskGroup(of: [CMMotionActivity]?.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                        switch (activities, error) {
                        case let (_, err?):
                            continuation.resume(throwing: err)
                        case let (list?, nil):
                            continuation.resume(returning: list)
                        default:
                            continuation.resume(returning: [])
                        }
                    }
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }

            guard let result = try await group.next() else {
                return nil
            }

            group.cancelAll()
            return result
        }
    }

    @MainActor func activityUpdates() -> AsyncStream<CMMotionActivity> {
        AsyncStream { continuation in
            startActivityUpdates(to: .main) { activity in
                guard let activity else {
                    continuation.finish()
                    return
                }
                continuation.yield(activity)
            }

            continuation.onTermination = { @Sendable _ in
                self.stopActivityUpdates()
            }
        }
    }

    @MainActor func requestAuthorization() async -> CMAuthorizationStatus {
        let startDate = Date().addingTimeInterval(-1)
        let endDate = Date()

        _ = try? await activities(from: startDate, to: endDate, timeout: 2)
        return CMMotionActivityManager.authorizationStatus()
    }
}

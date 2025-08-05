import CoreMotion
import Foundation

extension CMMotionActivityManager {
    @MainActor func activities(from start: Date, to end: Date) async throws -> [CMMotionActivity] {
        try await withCheckedThrowingContinuation { continuation in
            queryActivityStarting(from: start, to: end, to: .main) { activities, error in
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
}

extension CMMotionActivityManager {
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

        _ = try? await activities(from: startDate, to: endDate)
        return CMMotionActivityManager.authorizationStatus()
    }
}
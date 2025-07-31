import Foundation

struct MotionActivityGroup: Identifiable, Hashable {
    let id = UUID()
    let activityType: String
    let startDate: Date
    let endDate: Date
    let entryCount: Int

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

import CoreMotion
import SwiftUI

enum MotionActivityFormatters {
    private static let minGroupSize = 5

    static func confidenceText(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        @unknown default: "Unknown"
        }
    }

    static func activityTypes(_ activity: MotionActivity) -> AttributedString {
        var items: [(String, Color)] = []
        if activity.stationary { items.append(("Stationary", .red)) }
        if activity.walking { items.append(("Walking", .green)) }
        if activity.running { items.append(("Running", .orange)) }
        if activity.automotive { items.append(("Automotive", .blue)) }
        if activity.cycling { items.append(("Cycling", .purple)) }
        if activity.unknown { items.append(("Unknown", .yellow)) }
        if items.isEmpty { items = [("None", .secondary)] }

        var result = AttributedString()
        for (index, item) in items.enumerated() {
            var attr = AttributedString(item.0)
            attr.foregroundColor = item.1
            result += attr
            if index < items.count - 1 {
                result += AttributedString(", ")
            }
        }
        return result
    }

    // MARK: - Timeline Grouping Functions

    static func createActivityGroups(from activities: [MotionActivity]) -> [MotionActivityGroup] {
        let highConfidenceActivities = activities.filter { $0.confidence == .high }
        let singleTypeActivities = filterSingleActivityTypes(highConfidenceActivities)
        let sortedActivities = singleTypeActivities.sorted { $0.startDate < $1.startDate }
        let groups = groupConsecutiveActivities(sortedActivities)
        let filteredGroups = filterGroupsBySize(groups, minSize: minGroupSize)
        return filteredGroups.sorted { $0.startDate > $1.startDate }
    }

    private static func filterSingleActivityTypes(_ activities: [MotionActivity]) -> [MotionActivity] {
        activities.filter { activity in
            let activeTypes = [
                activity.stationary,
                activity.walking,
                activity.running,
                activity.automotive,
                activity.cycling,
                activity.unknown,
            ]
            return activeTypes.filter(\.self).count == 1
        }
    }

    private static func groupConsecutiveActivities(_ activities: [MotionActivity]) -> [MotionActivityGroup] {
        guard !activities.isEmpty else { return [] }

        var groups: [MotionActivityGroup] = []
        var currentGroup: [MotionActivity] = [activities[0]]

        for i in 1 ..< activities.count {
            let current = activities[i]
            let previous = activities[i - 1]

            if primaryActivityType(current) == primaryActivityType(previous) {
                currentGroup.append(current)
            } else {
                if let group = createGroup(from: currentGroup) {
                    groups.append(group)
                }
                currentGroup = [current]
            }
        }

        if let group = createGroup(from: currentGroup) {
            groups.append(group)
        }

        return groups
    }

    private static func filterGroupsBySize(_ groups: [MotionActivityGroup], minSize: Int) -> [MotionActivityGroup] {
        groups.filter { $0.entryCount > minSize }
    }

    private static func primaryActivityType(_ activity: MotionActivity) -> String {
        if activity.stationary { return "Stationary" }
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.automotive { return "Automotive" }
        if activity.cycling { return "Cycling" }
        if activity.unknown { return "Unknown" }
        return "None"
    }

    private static func createGroup(from activities: [MotionActivity]) -> MotionActivityGroup? {
        guard !activities.isEmpty else { return nil }

        let startDate = activities.first!.startDate
        let endDate = activities.last!.startDate
        let activityType = primaryActivityType(activities.first!)

        return MotionActivityGroup(
            activityType: activityType,
            startDate: startDate,
            endDate: endDate,
            entryCount: activities.count
        )
    }
}

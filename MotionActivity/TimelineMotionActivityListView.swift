import Foundation
import SwiftUI

struct TimelineMotionActivityListView: View {
    let activities: [MotionActivity]
    let isLoading: Bool
    let error: String?
    
    private static let minGroupSize = 5

    private var activityGroups: [MotionActivityGroup] {
        createActivityGroups(from: activities)
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading historical data...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error Loading Data")
                        .font(.headline)
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if activityGroups.isEmpty {
                ContentUnavailableView(
                    "No Activity Groups",
                    systemImage: "timeline.selection",
                    description: Text("No high-confidence activity groups found in the historical data.")
                )
            } else {
                List {
                    ForEach(activityGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(group.activityType)
                                    .font(.headline)
                                    .foregroundStyle(colorForActivityType(group.activityType))
                                Spacer()
                                Text(formatDuration(group.duration))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(formatTimeRange(start: group.startDate, end: group.endDate))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.entryCount) entries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func colorForActivityType(_ type: String) -> Color {
        switch type {
        case "Stationary": .red
        case "Walking": .green
        case "Running": .orange
        case "Automotive": .blue
        case "Cycling": .purple
        case "Unknown": .yellow
        default: .secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()

        // Check if dates are on the same day
        if Calendar.current.isDate(start, inSameDayAs: end) {
            formatter.dateFormat = "MMM d, h:mm a"
            let startString = formatter.string(from: start)
            formatter.dateFormat = "h:mm a"
            let endString = formatter.string(from: end)
            return "\(startString) - \(endString)"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            let startString = formatter.string(from: start)
            let endString = formatter.string(from: end)
            return "\(startString) - \(endString)"
        }
    }
    
    // MARK: - Timeline Grouping Functions
    
    private func createActivityGroups(from activities: [MotionActivity]) -> [MotionActivityGroup] {
        let highConfidenceActivities = activities.filter { $0.confidence == .high }
        let singleTypeActivities = filterSingleActivityTypes(highConfidenceActivities)
        let sortedActivities = singleTypeActivities.sorted { $0.startDate < $1.startDate }
        let groups = groupConsecutiveActivities(sortedActivities)
        let filteredGroups = filterGroupsBySize(groups, minSize: Self.minGroupSize)
        return filteredGroups.sorted { $0.startDate > $1.startDate }
    }
    
    private func filterSingleActivityTypes(_ activities: [MotionActivity]) -> [MotionActivity] {
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
    
    private func groupConsecutiveActivities(_ activities: [MotionActivity]) -> [MotionActivityGroup] {
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
    
    private func filterGroupsBySize(_ groups: [MotionActivityGroup], minSize: Int) -> [MotionActivityGroup] {
        groups.filter { $0.entryCount > minSize }
    }
    
    private func primaryActivityType(_ activity: MotionActivity) -> String {
        if activity.stationary { return "Stationary" }
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.automotive { return "Automotive" }
        if activity.cycling { return "Cycling" }
        if activity.unknown { return "Unknown" }
        return "None"
    }
    
    private func createGroup(from activities: [MotionActivity]) -> MotionActivityGroup? {
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

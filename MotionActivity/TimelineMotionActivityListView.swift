import Foundation
import SwiftUI

struct TimelineMotionActivityListView: View {
    let activities: [MotionActivity]
    let isLoading: Bool
    let error: String?

    private static let minGroupSize = 2
    private static let maxTimeGapSeconds: TimeInterval = 180

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
                                    .foregroundStyle(MotionActivityFormatters.colorForActivityType(group.activityType))
                                Spacer()
                                Text(MotionActivityFormatters.formatDuration(group.duration))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text(MotionActivityFormatters.formatTimeRange(start: group.startDate, end: group.endDate))
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

    // MARK: - Timeline Grouping Functions

    private func createActivityGroups(from activities: [MotionActivity]) -> [MotionActivityGroup] {
        let highConfidenceActivities = activities.filter { $0.confidence == .high }
        let nonStationaryOnlyActivities = filterStationaryOnlyActivities(highConfidenceActivities)
        let singleTypeActivities = filterSingleActivityTypes(nonStationaryOnlyActivities)
        let sortedActivities = singleTypeActivities.sorted { $0.startDate < $1.startDate }
        let groups = groupConsecutiveActivities(sortedActivities)
        let filteredGroups = filterGroupsBySize(groups, minSize: Self.minGroupSize)
        return filteredGroups.sorted { $0.startDate > $1.startDate }
    }

    private func filterStationaryOnlyActivities(_ activities: [MotionActivity]) -> [MotionActivity] {
        activities.filter { activity in
            // Filter out activities that are ONLY stationary
            !(activity.stationary &&
                !activity.walking &&
                !activity.running &&
                !activity.automotive &&
                !activity.cycling &&
                !activity.unknown)
        }
    }

    private func filterSingleActivityTypes(_ activities: [MotionActivity]) -> [MotionActivity] {
        activities.filter { activity in
            // Ignore stationary when counting active types
            let activeTypes = [
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

            let timeGap = current.startDate.timeIntervalSince(previous.startDate)
            let sameActivityType = primaryActivityType(current) == primaryActivityType(previous)
            let withinTimeThreshold = timeGap <= Self.maxTimeGapSeconds

            if sameActivityType, withinTimeThreshold {
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
        // Prioritize non-stationary activities
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.automotive { return "Automotive" }
        if activity.cycling { return "Cycling" }
        if activity.unknown { return "Unknown" }
        if activity.stationary { return "Stationary" }
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

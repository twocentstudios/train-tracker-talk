import Foundation
import SwiftUI

struct TimelineMotionActivityListView: View {
    let activities: [MotionActivity]
    let isLoading: Bool
    let error: String?

    private var activityGroups: [MotionActivityGroup] {
        MotionActivityFormatters.createActivityGroups(from: activities)
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
}

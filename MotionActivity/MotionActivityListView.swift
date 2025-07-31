import CoreMotion
import SwiftUI

struct MotionActivityListView: View {
    let activities: [MotionActivity]

    private var sortedActivities: [MotionActivity] {
        activities.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            ForEach(sortedActivities) { activity in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(activity.startDate, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(confidenceText(activity.confidence))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(activityTypes(activity))
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.plain)
    }

    private func confidenceText(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        @unknown default: "Unknown"
        }
    }

    private func activityTypes(_ activity: MotionActivity) -> AttributedString {
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
}
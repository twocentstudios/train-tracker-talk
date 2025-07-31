import CoreMotion
import SwiftUI

struct LiveMotionActivityListView: View {
    let activities: [MotionActivity]
    let isUpdating: Bool

    @State private var showOnlyHighConfidence = false

    private var sortedActivities: [MotionActivity] {
        let filtered = showOnlyHighConfidence
            ? activities.filter { $0.confidence == .high }
            : activities
        return filtered.sorted { $0.startDate > $1.startDate }
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
                        Text(MotionActivityFormatters.confidenceText(activity.confidence))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(MotionActivityFormatters.activityTypes(activity))
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isUpdating {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle("High Only", isOn: $showOnlyHighConfidence)
                    .toggleStyle(.button)
                    .controlSize(.small)
            }
        }
    }
}

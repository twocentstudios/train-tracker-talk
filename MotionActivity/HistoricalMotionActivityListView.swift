import CoreMotion
import SwiftUI

struct HistoricalMotionActivityListView: View {
    let activities: [MotionActivity]
    let isLoading: Bool
    let error: String?
    let onRefresh: () -> Void

    private var sortedActivities: [MotionActivity] {
        activities.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
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
            } else if sortedActivities.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Historical Data")
                        .font(.headline)
                    Text("No motion activity data found in the available history.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedActivities) { activity in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(activity.startDate, format: .dateTime.month().day().hour().minute().second())
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
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(
                    item: ExportableMotionActivityData(activities: activities),
                    preview: SharePreview("Motion Activity Export")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(activities.isEmpty)
            }
        }
    }
}

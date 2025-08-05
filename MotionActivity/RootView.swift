import SwiftUI

struct RootView: View {
    let store: RootStore

    var body: some View {
        ZStack {
            if !store.isMotionAvailable {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Motion & Fitness Not Available")
                        .font(.headline)
                    Text("This device doesn't support motion activity tracking.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.isAuthorized {
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.motion")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("Start Motion Activity Tracking")
                        .font(.headline)
                    Text("Tap the button below to begin collecting motion activity data.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Request Motion Permission") {
                        store.requestMotionPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView {
                    Tab("Live", systemImage: "dot.radiowaves.left.and.right") {
                        NavigationStack {
                            LiveMotionActivityListView(activities: store.liveActivities, isUpdating: store.isUpdating)
                                .navigationTitle("Live MotionActivity")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }

                    Tab("Historical", systemImage: "clock") {
                        NavigationStack {
                            HistoricalMotionActivityListView(
                                activities: store.historicalActivities,
                                isLoading: store.isLoadingHistorical,
                                error: store.historicalError,
                                onRefresh: { store.fetchHistoricalActivities() }
                            )
                            .navigationTitle("Historical MotionActivity")
                            .navigationBarTitleDisplayMode(.inline)
                            .onAppear {
                                store.fetchHistoricalActivities()
                            }
                        }
                    }

                    Tab("Timeline", systemImage: "timeline.selection") {
                        NavigationStack {
                            TimelineMotionActivityListView(
                                activities: store.historicalActivities,
                                isLoading: store.isLoadingHistorical,
                                error: store.historicalError
                            )
                            .navigationTitle("Activity Timeline")
                            .navigationBarTitleDisplayMode(.inline)
                            .onAppear {
                                store.fetchHistoricalActivities()
                            }
                        }
                    }
                }
            }
        }
        .task {
            store.startIfAuthorized()
        }
        .tint(.blue)
    }
}

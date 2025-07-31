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
            } else if store.activities.isEmpty {
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
                NavigationStack {
                    MotionActivityListView(activities: store.activities)
                        .navigationTitle("Motion Activity")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tint(.blue)
    }
}
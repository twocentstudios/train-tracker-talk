import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct RootView: View {
    let store: RootStore

    var body: some View {
        ZStack {
            if store.authorizationStatus != .authorizedAlways {
                Button("Request Authorization") {
                    store.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationStack {
                    LocationsListView()
                        .toolbarTitleDisplayMode(.inline)
                        .navigationTitle("Sessions")
                }
            }
        }
        .tint(Color(.accent))
    }
}

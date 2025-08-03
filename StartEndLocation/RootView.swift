import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct RootView: View {
    let store: RootStore

    var body: some View {
        ZStack {
            if !store.isMotionAuthorized {
                Button("Request Motion Authorization") {
                    store.requestMotionAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.authorizationStatus != .authorizedAlways {
                Button("Request Location Authorization") {
                    store.requestLocationAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationStack {
                    SessionsListView()
                        .toolbarTitleDisplayMode(.inline)
                        .navigationTitle("Sessions")
                }
            }
        }
        .tint(Color(.accent))
    }
}

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
                TabView {
                    Tab("List", systemImage: "list.bullet") {
                        NavigationStack {
                            LocationsListView()
                                .toolbarTitleDisplayMode(.inline)
                                .navigationTitle("Locations")
                        }
                    }

                    Tab("Map", systemImage: "map") {
                        NavigationStack {
                            LocationsMapView()
                                .toolbarVisibility(.hidden, for: .navigationBar)
                                .navigationTitle("Map")
                        }
                    }
                }
            }
        }
        .tint(Color(.accent))
    }
}

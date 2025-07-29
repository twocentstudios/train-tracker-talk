import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct RootView: View {
    let store: RootStore

    @ObservationIgnored
    @FetchAll(Location.order { $0.timestamp.desc() }, animation: .default)
    var locations

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
                            LocationsListView(locations: locations)
                                .toolbarTitleDisplayMode(.inline)
                                .navigationTitle("Locations")
                        }
                    }

                    Tab("Map", systemImage: "map") {
                        NavigationStack {
                            LocationsMapView(locations: locations)
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

import MapKit
import SwiftUI

struct LocationsMapView: View {
    let locations: [Location]

    private var mapCameraPosition: MapCameraPosition {
        guard !locations.isEmpty else {
            return .automatic
        }

        let coordinates = locations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        if coordinates.count == 1 {
            return .region(MKCoordinateRegion(center: coordinates[0], latitudinalMeters: 2000, longitudinalMeters: 2000))
        }

        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )

        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        Map(initialPosition: mapCameraPosition) {
            ForEach(locations) { location in
                let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)

                Marker(
                    location.timestamp.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()),
                    coordinate: coordinate
                )
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

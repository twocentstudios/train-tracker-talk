import MapKit
import SwiftUI

struct SessionDetailView: View {
    let sessionID: String

    private var sessionName: String {
        "Session \(sessionID)"
    }

    var body: some View {
        VSplitView {
            LocationMapView()
                .frame(minHeight: 300)

            LocationListView()
                .frame(minHeight: 200)
        }
        .navigationTitle(sessionName)
    }
}

struct LocationMapView: View {
    var body: some View {
        Map()
    }
}

struct LocationListView: View {
    private let sampleLocations = [
        "Location 1: 35.6762, 139.6503",
        "Location 2: 35.6812, 139.7671",
        "Location 3: 35.6895, 139.6917",
    ]

    var body: some View {
        List(sampleLocations, id: \.self) { location in
            Text(location)
                .font(.system(.body, design: .monospaced))
        }
        .navigationTitle("Locations")
    }
}

import MapKit
import SwiftUI

struct LocationsListView: View {
    let locations: [Location]

    private let columns: [GridItem] = [
        GridItem(.fixed(90), spacing: 4),
        GridItem(.fixed(140), spacing: 4),
        GridItem(.fixed(40), spacing: 4),
        GridItem(.fixed(50), spacing: 4),
        GridItem(.fixed(40), spacing: 4),
    ]

    var body: some View {
        ScrollView([.vertical]) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                Section {
                    Text(verbatim: "Time")
                        .font(.caption.monospacedDigit())
                    Text(verbatim: "Coordinates")
                        .font(.caption.monospacedDigit())
                    Text(verbatim: "Acc.")
                        .font(.caption.monospacedDigit())
                    Text(verbatim: "Speed")
                        .font(.caption.monospacedDigit())
                    Text(verbatim: "Cold")
                        .font(.caption.monospacedDigit())

                    ForEach(locations) { location in
                        let latitude = location.latitude.formatted(.number.precision(.fractionLength(4)))
                        let longitude = location.longitude.formatted(.number.precision(.fractionLength(4)))
                        let horizontalAccuracy = (location.horizontalAccuracy ?? 0).formatted(.number.precision(.fractionLength(1)))
                        let speed = (location.speed ?? 0).formatted(.number.precision(.significantDigits(2)))

                        Text(location.timestamp, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(verbatim: "(\(latitude), \(longitude))")
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                            .contextMenu(
                                menuItems: { Text(location.timestamp.formatted()) },
                                preview: {
                                    let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                                    let mapRegion: MapCameraPosition = .region(.init(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000))
                                    Map(initialPosition: mapRegion) {
                                        Marker(String(""), coordinate: coordinate)
                                    }
                                    .frame(width: 500, height: 500)
                                }
                            )

                        Text(verbatim: "\(horizontalAccuracy)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(speed)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)

                        Image(systemName: location.isFromColdLaunch ? "snowflake" : "circle")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(location.isFromColdLaunch ? .blue : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ExportDatabaseView()
            }
        }
    }
}

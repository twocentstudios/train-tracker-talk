import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct ShareDatabaseItem: Identifiable {
    let id = UUID()
    var url: URL?
}

struct ExportDatabaseView: View {
    @State private var shareItem: ShareDatabaseItem? = nil
    
    var body: some View {
        Group {
            if let shareItem {
                if let url = shareItem.url {
                    Menu {
                        ShareLink(item: url) {
                            Label("Share Database", systemImage: "square.and.arrow.up")
                        }
                        Button("Clear") {
                            self.shareItem = nil
                        }
                    } label: {
                        Label("Share Database", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                } else {
                    LabeledContent {
                        ProgressView()
                    } label: {
                        Label("Preparing Database...", systemImage: "square.3.layers.3d")
                    }
                }
            } else {
                Menu {
                    Button("Last Hour") { shareDatabase(interval: 60 * 60) }
                    Button("Last Day") { shareDatabase(interval: 24 * 60 * 60) }
                    Button("Last Week") { shareDatabase(interval: 7 * 24 * 60 * 60) }
                    Button("Last Month") { shareDatabase(interval: 30 * 24 * 60 * 60) }
                    Button("All Time") { shareDatabase(interval: nil) }
                } label: {
                    Label("Export Database", systemImage: "square.and.arrow.up")
                }
            }
        }
        .buttonStyle(.plain)
        .tint(Color(.accent))
    }
    
    private func shareDatabase(interval: TimeInterval?) {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        shareItem = .init(url: nil)
        Task {
            do {
                let url = try createShareDatabase(
                    database: database,
                    since: interval.map { now.addingTimeInterval(-$0) }
                )
                shareItem?.url = url
            } catch {
                print(error)
            }
        }
    }
}

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
                .tint(location.isFromColdLaunch ? .blue : .red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

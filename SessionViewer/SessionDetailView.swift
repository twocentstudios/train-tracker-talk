import Foundation
import GRDB
import MapKit
import SharingGRDB
import SwiftUI

private let iso8601Formatter = ISO8601DateFormatter()

struct SessionDetailView: View {
    let database: any DatabaseReader
    let sessionID: UUID

    @State private var locations: [Location] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var session: Session?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading session data...")
                        .foregroundStyle(.secondary)
                }
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Failed to load session")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VSplitView {
                    LocationMapView(locations: locations)
                        .frame(minHeight: 300)

                    LocationListView(locations: locations)
                        .frame(minHeight: 200)
                }
            }
        }
        .navigationTitle(session?.startDate.formatted(.dateTime.month().day().year().hour().minute()) ?? "Session")
        .task(id: sessionID) {
            await loadSessionData()
        }
    }

    private func loadSessionData() async {
        isLoading = true
        error = nil

        do {
            let result = try await database.read { db -> (Session?, [Location]) in
                let session = try Session.where { $0.id.eq(sessionID) }.fetchOne(db)
                let locations = try Location.where { $0.sessionID.eq(sessionID) }.order { $0.timestamp.asc() }.fetchAll(db)
                return (session, locations)
            }

            session = result.0
            locations = result.1
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

struct LocationMapView: View {
    let locations: [Location]

    private var mapRegion: MapCameraPosition {
        guard !locations.isEmpty else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        let coordinates = locations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.2, 0.001),
            longitudeDelta: max((maxLon - minLon) * 1.2, 0.001)
        )

        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        Map(position: .constant(mapRegion)) {
            ForEach(locations) { location in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                    Image(systemName: (location.horizontalAccuracy ?? 0) > 500 ? "xmark" : (location.course ?? -1) >= 0 ? "arrow.up" : "circle")
                        .symbolVariant(.fill)
                        .rotationEffect(.degrees((location.course ?? -1) >= 0 ? location.course! : 0))
                        .foregroundStyle(color(for: location.speed ?? -1))
                }
            }

            if locations.count > 1 {
                MapPolyline(coordinates: locations.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(.foreground, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .including([.publicTransport]), showsTraffic: false))
    }

    private func color(for speed: Double) -> Color {
        guard speed != -1 else { return .blue }
        let t = min(max((speed - 1) / 20, 0), 1)
        return Color(red: 1 - t, green: t, blue: 0)
    }
}

struct LocationListView: View {
    let locations: [Location]
    @State private var selectedLocationID: Location.ID?

    var body: some View {
        Group {
            if locations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No locations found")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("This session doesn't contain any location data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                Table(locations, selection: $selectedLocationID) {
                    TableColumn("Index") { location in
                        let index = locations.firstIndex(of: location)?.formatted(.number) ?? "-"
                        Text(index)
                    }
                    TableColumn("Time") { location in
                        Text(location.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3)))
                    }
                    TableColumn("Latitude") { location in
                        Text(location.latitude.formatted(.number.precision(.fractionLength(6))))
                    }
                    TableColumn("Longitude") { location in
                        Text(location.longitude.formatted(.number.precision(.fractionLength(6))))
                    }
                    TableColumn("Speed") { location in
                        if let speed = location.speed, speed > 0 {
                            Text(speed.formatted(.number.precision(.fractionLength(1))) + " m/s")
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Course") { location in
                        if let course = location.course, course >= 0 {
                            Text(course.formatted(.number.precision(.fractionLength(1))) + "°")
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Horizontal Accuracy") { location in
                        if let accuracy = location.horizontalAccuracy, accuracy > 0 {
                            Text("±\(accuracy.formatted(.number.precision(.fractionLength(0))))m")
                        } else {
                            Text("-")
                        }
                    }
                }
            }
        }
        .navigationTitle("Locations (\(locations.count))")
    }
}

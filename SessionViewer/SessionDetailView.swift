import Foundation
import GRDB
import MapKit
import SwiftUI

private let iso8601Formatter = ISO8601DateFormatter()

struct SessionDetailView: View {
    let database: any DatabaseReader
    let sessionID: String

    @State private var locations: [LocationData] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var sessionInfo: SessionInfo?

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
        .navigationTitle(sessionInfo?.displayName ?? "Session")
        .task(id: sessionID) {
            await loadSessionData()
        }
    }

    private func loadSessionData() async {
        isLoading = true
        error = nil

        do {
            let result = try await database.read { db -> (SessionInfo?, [LocationData]) in
                let sessionInfo = try SessionInfo.fetchOne(db, sessionID: sessionID)
                let locations = try LocationData.fetchAll(db, sessionID: sessionID)
                return (sessionInfo, locations)
            }

            await MainActor.run {
                sessionInfo = result.0
                locations = result.1
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
        }
    }
}

struct LocationMapView: View {
    let locations: [LocationData]

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
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }
            }

            if locations.count > 1 {
                MapPolyline(coordinates: locations.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(.blue, lineWidth: 2)
            }
        }
        .mapStyle(.standard)
    }
}

struct LocationListView: View {
    let locations: [LocationData]

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
                List(locations) { location in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(location.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3)))
                                .font(.headline)

                            Spacer()

                            if let speed = location.speed, speed > 0 {
                                Text("\(speed, specifier: "%.1f") m/s")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Text("\(location.latitude, specifier: "%.6f"), \(location.longitude, specifier: "%.6f")")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let accuracy = location.horizontalAccuracy, accuracy > 0 {
                            Text("Accuracy: ±\(accuracy, specifier: "%.0f")m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Locations (\(locations.count))")
    }
}

struct SessionInfo {
    let id: String
    let startDate: Date
    let endDate: Date?
    let isOnTrain: Bool

    var displayName: String {
        "Session - \(startDate.formatted(.dateTime.month().day().year().hour().minute()))"
    }
}

extension SessionInfo: FetchableRecord {
    init(row: Row) {
        id = row["id"]

        let startDateString: String = row["startDate"]
        startDate = iso8601Formatter.date(from: startDateString) ?? Date()

        if let endDateString: String? = row["endDate"], let endDateString {
            endDate = iso8601Formatter.date(from: endDateString)
        } else {
            endDate = nil
        }

        isOnTrain = row["isOnTrain"] == 1
    }

    static func fetchOne(_ db: Database, sessionID: String) throws -> SessionInfo? {
        try SessionInfo.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = ?", arguments: [sessionID])
    }
}

struct LocationData: Identifiable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let speed: Double?
    let horizontalAccuracy: Double?
}

extension LocationData: FetchableRecord {
    init(row: Row) {
        id = row["id"]
        latitude = row["latitude"]
        longitude = row["longitude"]

        let timestampString: String = row["timestamp"]
        timestamp = iso8601Formatter.date(from: timestampString) ?? Date()

        if let speedValue: Double = row["speed"], speedValue >= 0 {
            speed = speedValue
        } else {
            speed = nil
        }

        if let accuracyValue: Double = row["horizontalAccuracy"], accuracyValue > 0 {
            horizontalAccuracy = accuracyValue
        } else {
            horizontalAccuracy = nil
        }
    }

    static func fetchAll(_ db: Database, sessionID: String) throws -> [LocationData] {
        try LocationData.fetchAll(db, sql: """
        SELECT id, latitude, longitude, timestamp, speed, horizontalAccuracy
        FROM locations
        WHERE sessionID = ?
        ORDER BY timestamp ASC
        """, arguments: [sessionID])
    }
}

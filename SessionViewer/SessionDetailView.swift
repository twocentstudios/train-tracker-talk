import Foundation
import GRDB
import MapKit
import SharingGRDB
import SwiftUI

private let iso8601Formatter = ISO8601DateFormatter()

@MainActor @Observable final class SessionDetailStore: Identifiable {
    struct State {
        var locations: [Location] = []
        var session: Session?
        var isLoading = false
        var error: Error?
        var selectedLocationID: Location.ID?
    }

    var state = State()

    var selectedResult: RailwayTrackerResult? {
        guard let selectedLocationID = state.selectedLocationID else { return nil }
        return resultsCache[selectedLocationID]
    }

    var isPlaying: Bool { playbackTask != nil }

    let sessionID: UUID
    private(set) var resultsCache: [Location.ID: RailwayTrackerResult] = [:]
    private var playbackTask: Task<Void, Never>? = nil
    @ObservationIgnored private let database: any DatabaseReader
    @ObservationIgnored private var serialProcessor: SerialProcessor<Location, RailwayTrackerResult>?

    init(database: any DatabaseReader, sessionID: UUID) {
        self.database = database
        self.sessionID = sessionID
    }

    func loadSessionData() async {
        state.isLoading = true
        state.error = nil
        state.session = nil
        state.locations = []
        serialProcessor = nil

        do {
            let result = try await database.read { db -> (Session?, [Location]) in
                let session = try Session.where { $0.id.eq(sessionID) }.fetchOne(db)
                let locations = try Location.where { $0.sessionID.eq(sessionID) }.order { $0.timestamp.asc() }.fetchAll(db)
                return (session, locations)
            }

            state.session = result.0
            state.locations = result.1
            state.isLoading = false

            let railwayTracker = RailwayTracker(railwayDatabase: database)
            let serialProcessor = SerialProcessor(
                inputBuffering: .unbounded,
                outputBuffering: .bufferingNewest(1),
                process: { @Sendable input in
                    await railwayTracker.process(input)
                }
            )
            self.serialProcessor = serialProcessor

            Task {
                for location in state.locations {
                    serialProcessor.submit(location)
                }
            }

            for await result in serialProcessor.results {
                resultsCache[result.location.id] = result
            }
        } catch {
            state.error = error
            state.isLoading = false
        }
    }

    func togglePlayback() {
        if !isPlaying {
            playbackTask = Task { [weak self] in
                guard let self else { return }
                let locationIDs = state.locations.map(\.id)
                guard let firstLocationID = state.locations.first?.id else { return }
                let selectedLocationID = state.selectedLocationID ?? firstLocationID
                guard let selectedLocationIndex = locationIDs.firstIndex(of: selectedLocationID) else { return }
                let playbackLocationIDs = locationIDs.suffix(from: selectedLocationIndex)
                for locationID in playbackLocationIDs {
                    guard !Task.isCancelled else { break }
                    state.selectedLocationID = locationID
                    try? await Task.sleep(for: .seconds(0.1)) // TODO: var speed
                }
                playbackTask = nil
            }
        } else {
            playbackTask?.cancel()
            playbackTask = nil
        }
    }
}

struct SessionDetailView: View {
    @Bindable var store: SessionDetailStore

    var body: some View {
        VSplitView {
            LocationMapView(locations: store.state.locations)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)

            LocationListView(
                locations: store.state.locations,
                selectedLocationID: $store.state.selectedLocationID
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 200)
        }
        .overlay {
            if store.state.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading session data...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = store.state.error {
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
            }
        }
        .overlay(alignment: .top) {
            // TODO: debug only
            VStack {
                Text(store.selectedResult?.value ?? 0, format: .number)
                    .font(.largeTitle.bold())
                    .padding()
                Text(store.resultsCache.count, format: .number)
                    .font(.title3)
            }
            .padding()
            .background(Material.ultraThick)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    store.togglePlayback()
                } label: {
                    Image(systemName: store.isPlaying ? "pause" : "play")
                }
            }
        }
        .navigationTitle(store.state.session?.startDate.formatted(.dateTime.month().day().year().hour().minute()) ?? "Session")
        .task(id: store.sessionID) {
            await store.loadSessionData()
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
    @Binding var selectedLocationID: Location.ID?

    var body: some View {
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
        .navigationTitle("Locations (\(locations.count))")
    }
}

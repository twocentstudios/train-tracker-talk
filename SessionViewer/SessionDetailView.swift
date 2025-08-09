import Foundation
import GRDB
import MapKit
import SharingGRDB
import SwiftUI

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

    var currentLocationIndex: Int {
        guard let selectedLocationID = state.selectedLocationID else { return 0 }
        return state.locations.firstIndex { $0.id == selectedLocationID } ?? 0
    }

    var isPlaying: Bool { playbackTask != nil }

    let sessionID: UUID
    private(set) var resultsCache: [Location.ID: RailwayTrackerResult] = [:]
    private var playbackTask: Task<Void, Never>? = nil
    var playbackSpeedMultiplier: Double = 0.1
    var cameraPosition: MapCameraPosition = .automatic
    var isShowingDetailedPolyline: Bool = false
    let playingTrailLength: Int = 50
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
                for (index, locationID) in playbackLocationIDs.enumerated() {
                    guard !Task.isCancelled else { break }
                    state.selectedLocationID = locationID

                    if index + 1 < playbackLocationIDs.count {
                        let currentLocation = state.locations.first { $0.id == locationID }
                        let nextLocationID = playbackLocationIDs[playbackLocationIDs.index(playbackLocationIDs.startIndex, offsetBy: index + 1)]
                        let nextLocation = state.locations.first { $0.id == nextLocationID }

                        if let currentLocation, let nextLocation {
                            let waitTime = nextLocation.timestamp.timeIntervalSince(currentLocation.timestamp)
                            let maxWaitTime: TimeInterval = 10
                            let effectiveWaitTime: TimeInterval = playbackSpeedMultiplier * min(waitTime, maxWaitTime)
                            try? await Task.sleep(for: .milliseconds(Int(effectiveWaitTime * 1000)))
                        } else {
                            try? await Task.sleep(for: .seconds(0.1))
                        }
                    }
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
            LocationMapView(store: store)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)

            LocationListView(
                locations: store.state.locations,
                selectedLocationID: $store.state.selectedLocationID
            )
            .disabled(store.isPlaying)
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
            ToolbarItemGroup {
                Button {
                    store.togglePlayback()
                } label: {
                    Image(systemName: store.isPlaying ? "pause" : "play")
                }
                .disabled(store.state.isLoading)

                Picker("Playback Speed", selection: $store.playbackSpeedMultiplier) {
                    ForEach([0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.0], id: \.self) { speed in
                        Text("\((1 / speed).formatted(.number.precision(.significantDigits(2))))x").tag(speed)
                    }
                }
                .disabled(store.isPlaying || store.state.isLoading)
                .pickerStyle(.menu)

                Toggle("Show Detailed Polyline", systemImage: "chart.xyaxis.line", isOn: $store.isShowingDetailedPolyline)
                    .disabled(store.isPlaying || store.state.isLoading)
            }
        }
        .navigationTitle(store.state.session?.startDate.formatted(.dateTime.month().day().year().hour().minute()) ?? "Session")
        .task(id: store.sessionID) {
            await store.loadSessionData()
        }
        .onKeyPress(.escape) {
            if store.isPlaying {
                store.togglePlayback()
            } else {
                store.state.selectedLocationID = nil
            }
            return .handled
        }
    }
}

struct LocationMapView: View {
    @Bindable var store: SessionDetailStore

    private var displayedLocations: [Location] {
        let playingTrailLength = store.playingTrailLength
        let locations = store.state.locations
        let isPlaying = store.isPlaying
        let selectedLocationID = store.state.selectedLocationID

        if isPlaying {
            let currentIndex = store.currentLocationIndex
            let startIndex = max(0, currentIndex - playingTrailLength + 1)
            let endIndex = min(currentIndex + 1, locations.count)
            return Array(locations[startIndex ..< endIndex])
        } else if let selectedLocationID,
                  let selectedLocation = locations.first(where: { $0.id == selectedLocationID })
        {
            return [selectedLocation]
        } else {
            return locations
        }
    }

    var body: some View {
        Map(position: $store.cameraPosition) {
            let locations = displayedLocations
            let playingTrailLength = store.playingTrailLength

            if locations.count <= playingTrailLength || store.isShowingDetailedPolyline {
                ForEach(locations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        Image(systemName: (location.horizontalAccuracy ?? 0) > 500 ? "xmark" : (location.course ?? -1) >= 0 ? "arrow.up" : "circle")
                            .symbolVariant(store.state.selectedLocationID == location.id ? .fill : .circle)
                            .rotationEffect(.degrees((location.course ?? -1) >= 0 ? location.course! : 0))
                            .foregroundStyle(color(for: location.speed ?? -1))
                            .scaleEffect(store.state.selectedLocationID == location.id ? 2.0 : 1.0)
                            .onTapGesture {
                                store.state.selectedLocationID = location.id
                            }
                    }
                }
            } else {
                MapPolyline(coordinates: locations.map(\.coordinate))
                    .stroke(.foreground, lineWidth: 4)
                if let startLocation = locations.first,
                   let endLocation = locations.last
                {
                    Marker("Start", coordinate: startLocation.coordinate)
                    Marker("End", coordinate: endLocation.coordinate)
                }
            }
        }
        .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .including([.publicTransport]), showsTraffic: false))
        .onChange(of: store.state.selectedLocationID) { _, newSelectedLocationID in
            if let newSelectedLocationID, !store.isPlaying {
                guard let location = store.state.locations.first(where: { $0.id == newSelectedLocationID }) else { return }
                let coordinate = location.coordinate
                store.cameraPosition = MapCameraPosition.region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008)
                    )
                )
            } else {
                store.cameraPosition = .automatic
            }
        }
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
        ScrollViewReader { proxy in
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
            .onChange(of: selectedLocationID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

extension Location {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

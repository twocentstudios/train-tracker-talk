import Foundation
import GRDB
import MapKit
import SharingGRDB
import SwiftUI

@MainActor @Observable final class SessionDetailStore: Identifiable {
    var locations: [Location] = []
    var session: Session?
    var isLoading = false
    var error: Error?
    var selectedLocationID: Location.ID?
    var userSelectedRailway: Railway.ID?
    var selectedStationRailDirection: StationRailDirection?
    var playbackSpeedMultiplier: Double = 0.1
    var cameraPosition: MapCameraPosition = .automatic
    var isShowingDetailedPolyline: Bool = false

    let sessionID: UUID
    private(set) var resultsCache: [Location.ID: RailwayTrackerResult] = [:]
    private var playbackTask: Task<Void, Never>? = nil
    let playingTrailLength: Int = 50

    @ObservationIgnored private let sessionsDatabase: any DatabaseReader
    @ObservationIgnored private let railwayDatabase: any DatabaseReader
    @ObservationIgnored private var serialProcessor: SerialProcessor<Location, RailwayTrackerResult>?

    var selectedResult: RailwayTrackerResult? {
        guard let selectedLocationID else { return nil }
        return resultsCache[selectedLocationID]
    }

    var selectedCandidate: RailwayTrackerCandidate? {
        guard let candidates = selectedResult?.candidates else { return nil }
        if let userSelectedCandidate = candidates.first(where: { $0.railway.id == userSelectedRailway }) {
            return userSelectedCandidate
        } else if let firstCandidate = candidates.first {
            return firstCandidate
        } else {
            return nil
        }
    }

    var selectedStationLocationHistory: StationDirectionalLocationHistory? {
        guard let selectedStationRailDirection else { return nil }
        return selectedResult?.stationLocationHistories[selectedStationRailDirection]
    }

    var currentLocationIndex: Int {
        guard let selectedLocationID else { return 0 }
        return locations.firstIndex { $0.id == selectedLocationID } ?? 0
    }

    var isPlaying: Bool { playbackTask != nil }

    var displayedProcessingProgress: Double? {
        let current = resultsCache.count
        let total = locations.count
        
        // Return nil when processing is complete
        guard current < total else { return nil }
        guard total > 0 else { return nil }
        
        let actualProgress = Double(current) / Double(total)
        
        // Quantize to 5% increments (0.05, 0.10, 0.15, etc.)
        let quantizationStep = 0.05
        let quantizedProgress = floor(actualProgress / quantizationStep) * quantizationStep
        
        // Ensure we show at least some progress initially
        return max(quantizedProgress, 0.01)
    }

    init(sessionsDatabase: any DatabaseReader, railwayDatabase: any DatabaseReader, sessionID: UUID) {
        self.sessionsDatabase = sessionsDatabase
        self.railwayDatabase = railwayDatabase
        self.sessionID = sessionID
    }

    func loadSessionData() async {
        isLoading = true
        error = nil
        session = nil
        locations = []
        serialProcessor = nil

        do {
            let result = try await sessionsDatabase.read { db -> (Session?, [Location]) in
                let session = try Session.where { $0.id.eq(sessionID) }.fetchOne(db)
                let locations = try Location.where { $0.sessionID.eq(sessionID) }.order { $0.timestamp.asc() }.fetchAll(db)
                return (session, locations)
            }

            session = result.0
            locations = result.1
            isLoading = false

            let railwayTracker = RailwayTracker(railwayDatabase: railwayDatabase)
            let serialProcessor = SerialProcessor(
                inputBuffering: .unbounded,
                outputBuffering: .unbounded, // can be `1` when piping directly to UI
                process: { @Sendable input in
                    await railwayTracker.process(input)
                }
            )
            self.serialProcessor = serialProcessor

            Task {
                for location in locations {
                    serialProcessor.submit(location)
                }
            }

            for await result in serialProcessor.results {
                resultsCache[result.location.id] = result
            }
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func togglePlayback() {
        if !isPlaying {
            playbackTask = Task { [weak self] in
                guard let self else { return }
                let locationIDs = locations.map(\.id)
                guard let firstLocationID = locations.first?.id else { return }
                let selectedLocationID = selectedLocationID ?? firstLocationID
                guard let selectedLocationIndex = locationIDs.firstIndex(of: selectedLocationID) else { return }
                let playbackLocationIDs = locationIDs.suffix(from: selectedLocationIndex)
                for (index, locationID) in playbackLocationIDs.enumerated() {
                    guard !Task.isCancelled else { break }
                    self.selectedLocationID = locationID

                    if index + 1 < playbackLocationIDs.count {
                        let currentLocation = locations.first { $0.id == locationID }
                        let nextLocationID = playbackLocationIDs[playbackLocationIDs.index(playbackLocationIDs.startIndex, offsetBy: index + 1)]
                        let nextLocation = locations.first { $0.id == nextLocationID }

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
        HSplitView {
            VSplitView {
                LocationMapView(store: store)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)

                LocationListView(
                    locations: store.locations,
                    selectedLocationID: $store.selectedLocationID
                )
                .disabled(store.isPlaying)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
            }

            RailwayTrackerSidebar(store: store)
                .frame(idealWidth: 300)
                .fixedSize(horizontal: true, vertical: false)
        }
        .overlay {
            if store.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading session data...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = store.error {
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
        .toolbar {
            ToolbarItemGroup {
                if let progress = store.displayedProcessingProgress {
                    ProgressView("Processing...", value: progress, total: 1.0)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.togglePlayback()
                } label: {
                    Image(systemName: store.isPlaying ? "pause" : "play")
                }
                .disabled(store.isLoading)

                Picker("Playback Speed", selection: $store.playbackSpeedMultiplier) {
                    ForEach([0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.0], id: \.self) { speed in
                        Text("\((1 / speed).formatted(.number.precision(.significantDigits(2))))x").tag(speed)
                    }
                }
                .disabled(store.isPlaying || store.isLoading)
                .pickerStyle(.menu)

                Toggle("Show Detailed Polyline", systemImage: "chart.xyaxis.line", isOn: $store.isShowingDetailedPolyline)
                    .disabled(store.isPlaying || store.isLoading)
            }
        }
        .navigationTitle(store.session?.startDate.formatted(.dateTime.month().day().year().hour().minute()) ?? "Session")
        .task(id: store.sessionID) {
            await store.loadSessionData()
        }
        .onKeyPress(.escape) {
            if store.isPlaying {
                store.togglePlayback()
            } else {
                store.selectedLocationID = nil
            }
            return .handled
        }
    }
}

struct LocationMapView: View {
    @Bindable var store: SessionDetailStore

    private var displayedLocations: [Location] {
        // If a station is selected, show station-specific locations
        if let stationHistory = store.selectedStationLocationHistory {
            var stationLocations: [Location] = []
            stationLocations.append(contentsOf: stationHistory.visitingLocations)
            stationLocations.append(contentsOf: stationHistory.approachingLocations)
            if let firstDeparture = stationHistory.firstDepartureLocation {
                stationLocations.append(firstDeparture)
            }
            return stationLocations
        }

        // Otherwise use the normal logic
        let playingTrailLength = store.playingTrailLength
        let locations = store.locations
        let isPlaying = store.isPlaying
        let selectedLocationID = store.selectedLocationID

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
    
    private var appropriateMapRegion: MKCoordinateRegion? {
        let isStationMode = store.selectedStationLocationHistory != nil
        let isPlaying = store.isPlaying
        let hasSelectedLocation = store.selectedLocationID != nil
        
        if isStationMode {
            // Station selected: fit all station locations
            return regionThatFits(displayedLocations, padding: 0.3)
        } else if hasSelectedLocation && !isPlaying {
            // Single location selected: center on it
            return regionThatFits(displayedLocations, padding: 0.0)
        } else if isPlaying {
            // Playing: fit current trail segment
            return regionThatFits(displayedLocations, padding: 0.1)
        } else {
            // No specific selection: fit all locations or return nil for automatic
            return displayedLocations.count > 100 ? nil : regionThatFits(displayedLocations, padding: 0.1)
        }
    }

    var body: some View {
        Map(position: $store.cameraPosition) {
            let locations = displayedLocations
            let playingTrailLength = store.playingTrailLength
            let isStationMode = store.selectedStationLocationHistory != nil

            if isStationMode {
                // Station mode: show colored circles for station-specific locations
                ForEach(locations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        Circle()
                            .fill(stationLocationColor(for: location))
                            .frame(width: 9, height: 9)
                            .onTapGesture {
                                store.selectedLocationID = location.id
                            }
                    }
                }
            } else if locations.count <= playingTrailLength || store.isShowingDetailedPolyline {
                ForEach(locations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        Image(systemName: (location.horizontalAccuracy ?? 0) > 500 ? "xmark" : (location.course ?? -1) >= 0 ? "arrow.up" : "circle")
                            .symbolVariant(store.selectedLocationID == location.id ? .fill : .circle)
                            .rotationEffect(.degrees((location.course ?? -1) >= 0 ? location.course! : 0))
                            .foregroundStyle(color(for: location.speed ?? -1))
                            .scaleEffect(store.selectedLocationID == location.id ? 2.0 : 1.0)
                            .onTapGesture {
                                store.selectedLocationID = location.id
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
        .onChange(of: store.selectedLocationID) { _, newSelectedLocationID in
            // Only clear station selection if it doesn't exist in the new location's results
            if let selectedStation = store.selectedStationRailDirection,
               let newResult = store.selectedResult
            {
                // Check if the selected station still exists in the new result's stationLocationHistories
                if newResult.stationLocationHistories[selectedStation] == nil {
                    // Station doesn't exist in new results, clear selection
                    store.selectedStationRailDirection = nil
                }
                // Otherwise keep the selection
            } else if store.selectedStationRailDirection != nil {
                // No result available, clear selection
                store.selectedStationRailDirection = nil
            }

            if newSelectedLocationID != nil, !store.isPlaying {
                // Use smart bounds calculation
                if let region = appropriateMapRegion {
                    store.cameraPosition = MapCameraPosition.region(region)
                } else {
                    store.cameraPosition = .automatic
                }
            } else {
                store.cameraPosition = .automatic
            }
        }
        .onChange(of: store.selectedStationRailDirection) { _, newStationSelection in
            // Update camera when station selection changes
            if let region = appropriateMapRegion {
                store.cameraPosition = MapCameraPosition.region(region)
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

    private func stationLocationColor(for location: Location) -> Color {
        guard let stationHistory = store.selectedStationLocationHistory else { return .blue }
        
        let isVisiting = stationHistory.visitingLocations.contains(where: { $0.id == location.id })
        let isApproaching = stationHistory.approachingLocations.contains(where: { $0.id == location.id })
        let isDeparture = stationHistory.firstDepartureLocation?.id == location.id

        if isDeparture && isVisiting {
            return .purple
        } else if isDeparture && isApproaching {
            return .yellow
        } else if isVisiting {
            return .green
        } else if isApproaching {
            return .orange
        } else if isDeparture {
            return .red
        } else {
            return .blue
        }
    }
    
    private func regionThatFits(_ locations: [Location], padding: Double = 0.2) -> MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }
        
        if locations.count == 1 {
            // Single location - return a small region centered on it
            let location = locations[0]
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        }
        
        // Multiple locations - calculate bounding box
        let coordinates = locations.map(\.coordinate)
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        
        let latDelta = maxLat - minLat
        let lonDelta = maxLon - minLon
        
        // Add padding (minimum span to avoid overly tight bounds)
        let paddedLatDelta = max(latDelta * (1 + padding), 0.002)
        let paddedLonDelta = max(lonDelta * (1 + padding), 0.002)
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: paddedLatDelta, longitudeDelta: paddedLonDelta)
        )
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
                TableColumn("ID") { location in
                    let idString = location.id.uuidString
                    let suffix = String(idString.suffix(4))
                    Text(suffix)
                        .font(.system(.caption, design: .monospaced))
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

struct RailwayTrackerSidebar: View {
    @Bindable var store: SessionDetailStore

    var body: some View {
        List {
            Section {
                if let candidates = store.selectedResult?.candidates, let selectedCandidate = store.selectedCandidate {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(candidates, id: \.railway.id) { candidate in
                                let isSelected = candidate.railway.id == selectedCandidate.railway.id
                                let isUserSelected = candidate.railway.id == store.userSelectedRailway
                                Button {
                                    if isUserSelected {
                                        store.userSelectedRailway = nil
                                    } else {
                                        store.userSelectedRailway = candidate.railway.id
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        VStack(spacing: 1) {
                                            Text(candidate.railway.title.en)
                                                .bold(isSelected)
                                                .font(.body.width(.compressed))
                                            if let score = store.selectedResult?.railwayScores[candidate.railway.id],
                                               let selectedScore = store.selectedResult?.railwayScores[selectedCandidate.railway.id]
                                            {
                                                let scoreDiff = score - selectedScore
                                                let displayScore = !isSelected ? scoreDiff : score
                                                Text(displayScore.formatted(.number.precision(.significantDigits(6))))
                                                    .font(.caption2)
                                                    .monospaced()
                                            }
                                        }
                                        if isUserSelected {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Material.regular)
                                                .transition(.scale(0.6).combined(with: .opacity))
                                        }
                                    }
                                    .animation(.smooth(duration: 0.2), value: isUserSelected)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background { Capsule().fill(isSelected ? Material.ultraThin : Material.regular) }
                                    .background { isSelected ? Capsule().fill(Color(hexString: candidate.railway.color, alpha: 1.0)) : nil }
                                    .overlay { Capsule().strokeBorder(Color(hexString: candidate.railway.color), lineWidth: 2) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
                if let selectedCandidate = store.selectedCandidate {
                    candidateCard(candidate: selectedCandidate)
                }
            } header: {
                Text(verbatim: "Candidates")
            }

            Section {
                if let selectedCandidate = store.selectedCandidate {
                    let railway = selectedCandidate.railway
                    let stationIDs = selectedCandidate.railwayDirection == railway.ascending ? railway.stations : railway.stations.reversed()

                    if stationIDs.isEmpty {
                        Text("No stations found")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(stationIDs, id: \.self) { stationID in
                            if let railwayDirection = selectedCandidate.railwayDirection {
                                let stationRailDirection = StationRailDirection(stationID: stationID, railDirection: railwayDirection)
                                let hasHistory = store.selectedResult?.stationPhaseHistories[stationRailDirection]?.items.isEmpty == false
                                if hasHistory {
                                    stationRow(for: stationID, candidate: selectedCandidate)
                                }
                            }
                        }
                    }
                } else {
                    Text("No candidate selected")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } header: {
                Text(verbatim: "Railway Stations")
            }

            Section {
                if let result = store.selectedResult {
                    let scores = result.instantaneousRailwayCoordinateScores.sorted(by: { $0.value > $1.value })
                    if scores.isEmpty {
                        Text("No railway coordinate scores")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(scores, id: \.0) { pair in
                            LabeledContent(pair.0.rawValue) {
                                HStack {
                                    if let ascendingScore = result.instantaneousRailwayAscendingScores[pair.0] {
                                        Text(ascendingScore.formatted(.number.precision(.fractionLength(3))))
                                            .monospaced()
                                    }
                                    Text(pair.1.formatted(.number.precision(.significantDigits(3))))
                                        .monospaced()
                                }
                            }
                        }
                    }
                } else {
                    Text("No location selected")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } header: {
                Text(verbatim: "Insta Railway Coord")
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder func stationRow(for stationID: Station.ID, candidate: RailwayTrackerCandidate) -> some View {
        if let railwayDirection = candidate.railwayDirection {
            let stationRailDirection = StationRailDirection(stationID: stationID, railDirection: railwayDirection)
            let isSelected = store.selectedStationRailDirection == stationRailDirection

            Button {
                if isSelected {
                    store.selectedStationRailDirection = nil
                } else {
                    store.selectedStationRailDirection = stationRailDirection
                }
            } label: {
                HStack {
                    Text(stationID.rawValue.split(separator: ".").last?.description ?? stationID.rawValue)
                        .foregroundStyle(isSelected ? .primary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())

                    let lastPhase = store.selectedResult?.stationPhaseHistories[stationRailDirection]?.items.last?.phase
                    Menu {
                        if let items = store.selectedResult?.stationPhaseHistories[stationRailDirection]?.items {
                            if items.isEmpty {
                                Text("No phase history")
                            } else {
                                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                    Text("\(String(describing: item.phase)) - \(item.date.formatted(.dateTime.hour().minute().second()))")
                                }
                            }
                        } else {
                            Text("No phase history")
                        }
                    } label: {
                        Text(lastPhase.map(String.init(describing:)) ?? "-")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Text(stationID.rawValue.split(separator: ".").last?.description ?? stationID.rawValue)
                Spacer()
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }

    @ViewBuilder func candidateCard(candidate: RailwayTrackerCandidate) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(candidate.railway.title.en)
                    .font(.title3.width(.compressed))
                    .padding(.leading, 9)
                    .overlay(alignment: .leading) {
                        let railwayHexColor = candidate.railway.color
                        RoundedRectangle(cornerRadius: 2).fill(Color(hexString: railwayHexColor)).frame(width: 4).padding(.vertical, 2)
                    }
                Spacer()
                if let railwayDestination = candidate.railwayDestinationStation?.title {
                    Text("to \(railwayDestination.en)")
                        .font(.body.width(.compressed))
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.smooth, value: candidate.railway)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let station = candidate.focusStation,
                   let stationPhase = candidate.focusStationPhase
                {
                    Text(station.title.en)
                        .id(station.id)
                        .font(.largeTitle.bold().width(.compressed))
                        .lineLimit(1)
                        .layoutPriority(1)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top).combined(with: .opacity)))
                    Text(stationPhase.debugDescription)
                        .font(.title.width(.compressed))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.secondary)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top).combined(with: .opacity)))
                        .id(stationPhase)
                } else {
                    Text(verbatim: "------")
                        .redacted(reason: .placeholder)
                        .font(.title.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.smooth, value: candidate.focusStationPhase)
            if let laterStation = candidate.laterStation {
                VStack(alignment: .leading, spacing: 0) {
                    Text(laterStation.title.en)
                        .id(laterStation.id)
                        .lineLimit(1)
                        .font(.title3.width(.compressed))
                        .padding(.vertical, 6)
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(.clear)
                                .overlay { Rectangle().fill(.secondary).frame(width: 1) }
                                .overlay { Circle().inset(by: 3).fill(.primary) }
                                .frame(width: 13)
                        }
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top).combined(with: .opacity)))
                    if let laterLaterStation = candidate.laterLaterStation {
                        Text(laterLaterStation.title.en)
                            .id(laterLaterStation.id)
                            .lineLimit(1)
                            .font(.title3.width(.compressed))
                            .padding(.vertical, 6)
                            .padding(.leading, 16)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(.clear)
                                    .overlay { Rectangle().fill(.secondary).frame(width: 1) }
                                    .overlay { Circle().inset(by: 3).fill(.primary) }
                                    .frame(width: 13)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .animation(.smooth, value: candidate.laterStation)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}

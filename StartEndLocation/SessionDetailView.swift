import CoreLocation
import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchAll var locations: [Location]

    @ObservationIgnored
    @FetchAll var motionActivities: [MotionActivity]

    @State private var notes: String
    @State private var selectedSection: DetailSection = .locations
    @State private var isMapOnlyMode: Bool = false

    enum DetailSection: String, CaseIterable {
        case motionActivity = "Motion Activity"
        case locations = "Locations"
    }

    init(session: Session) {
        self.session = session
        _locations = FetchAll(
            Location
                .where { $0.sessionID.eq(session.id) }
                .order { $0.timestamp.asc() },
            animation: .default
        )
        _motionActivities = FetchAll(
            MotionActivity
                .where { $0.sessionID.eq(session.id) }
                .order { $0.startDate.asc() },
            animation: .default
        )
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isMapOnlyMode {
                    // Map-only mode
                    Map(initialPosition: .automatic) {
                        if locations.count > 1 {
                            let coordinates = locations.map { location in
                                CLLocationCoordinate2D(
                                    latitude: location.latitude,
                                    longitude: location.longitude
                                )
                            }
                            MapPolyline(coordinates: coordinates)
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Full view mode
                    // Session Stats Header
                    SessionStatsView(session: session, locations: locations)
                        .padding()
                        .background(Color(.systemGroupedBackground))

                    Map(initialPosition: .automatic) {
                        if locations.count > 1 {
                            let coordinates = locations.map { location in
                                CLLocationCoordinate2D(
                                    latitude: location.latitude,
                                    longitude: location.longitude
                                )
                            }
                            MapPolyline(coordinates: coordinates)
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    .frame(maxHeight: 200)

                    VStack(spacing: 0) {
                        // Section Picker
                        Picker("Section", selection: $selectedSection) {
                            ForEach(DetailSection.allCases, id: \.self) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        List {
                            switch selectedSection {
                            case .motionActivity:
                                if !motionActivities.isEmpty {
                                    Section("Motion Activity (\(motionActivities.count))") {
                                        ForEach(motionActivities) { activity in
                                            MotionActivityRowView(activity: activity)
                                        }
                                    }
                                } else {
                                    Section("Motion Activity") {
                                        Text("No motion activity data")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }

                            case .locations:
                                Section("Locations (\(locations.count))") {
                                    ForEach(locations) { location in
                                        LocationRowView(location: location)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)

                    HStack {
                        TextField("Notes", text: $notes)
                            .textFieldStyle(.roundedBorder)

                        Button("Save") {
                            saveNotes()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(notes == (session.notes ?? ""))
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .navigationTitle(session.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isMapOnlyMode.toggle()
                    } label: {
                        Image(systemName: isMapOnlyMode ? "list.bullet" : "map")
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveNotes() {
        withErrorReporting {
            try database.write { db in
                try Session
                    .where { $0.id.eq(session.id) }
                    .update { $0.notes = notes.isEmpty ? nil : notes }
                    .execute(db)
            }
        }
    }
}

struct SessionStatsView: View {
    let session: Session
    let locations: [Location]

    private var maxSpeed: Double {
        locations.compactMap(\.speed).max() ?? 0
    }

    private var distance: Double {
        guard locations.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1 ..< locations.count {
            let loc1 = CLLocation(latitude: locations[i - 1].latitude, longitude: locations[i - 1].longitude)
            let loc2 = CLLocation(latitude: locations[i].latitude, longitude: locations[i].longitude)
            total += loc1.distance(from: loc2)
        }
        return total
    }

    var body: some View {
        VStack(spacing: 12) {
            // Status row
            HStack {
                Label(session.isComplete ? "Complete" : "Active",
                      systemImage: session.isComplete ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(session.isComplete ? .green : .orange)

                Spacer()

                if session.isOnTrain {
                    Label("Train Detected", systemImage: "tram.fill")
                        .foregroundStyle(.purple)
                }
            }
            .font(.caption)

            // Stats grid
            HStack(spacing: 16) {
                StatItem(title: "Duration", value: session.durationFormatted)
                StatItem(title: "Locations", value: "\(locations.count)")
                StatItem(title: "Max Speed", value: "\(maxSpeed.formatted(.number.precision(.fractionLength(1)))) m/s")
                StatItem(title: "Distance", value: "\(Int(distance)) m")
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MotionActivityRowView: View {
    let activity: MotionActivity

    private var activityType: String {
        if activity.walking { return "Walking" }
        if activity.running { return "Running" }
        if activity.automotive { return "Automotive" }
        if activity.cycling { return "Cycling" }
        if activity.stationary { return "Stationary" }
        if activity.unknown { return "Unknown" }
        return "None"
    }

    private var activityIcon: String {
        if activity.walking { return "figure.walk" }
        if activity.running { return "figure.run" }
        if activity.automotive { return "car.fill" }
        if activity.cycling { return "bicycle" }
        if activity.stationary { return "figure.stand" }
        return "questionmark.circle"
    }

    var body: some View {
        HStack {
            Image(systemName: activityIcon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(activityType)
                .font(.system(.body, design: .rounded))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.startDate, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                    .font(.system(.caption, design: .monospaced))

                Text(activity.confidence.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(activity.confidence == .high ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
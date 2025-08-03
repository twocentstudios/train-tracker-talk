import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct LocationsListView: View {
    @ObservationIgnored
    @FetchAll(
        Session.all.order { $0.startDate.desc() },
        animation: .default
    )
    var sessions: [Session]

    @State private var selectedSession: Session?

    var body: some View {
        List {
            ForEach(sessions) { session in
                SessionRowView(session: session) {
                    selectedSession = session
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ExportDatabaseView()
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(session.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if session.isFromColdLaunch {
                    Spacer()
                    Image(systemName: "snowflake")
                        .foregroundStyle(.secondary)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .cornerRadius(4)
                        .imageScale(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
    }
}

struct SessionDetailView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchAll var locations: [Location]

    @State private var notes: String

    init(session: Session) {
        self.session = session
        _locations = FetchAll(
            Location
                .where { $0.sessionID.eq(session.id) }
                .order { $0.timestamp.asc() },
            animation: .default
        )
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .frame(maxHeight: .infinity)

                List {
                    ForEach(locations) { location in
                        LocationRowView(location: location)
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
            .navigationTitle(session.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

struct LocationRowView: View {
    let location: Location

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3)))
                    .font(.system(.caption, design: .monospaced))

                let latitude = location.latitude.formatted(.number.precision(.fractionLength(7)))
                let longitude = location.longitude.formatted(.number.precision(.fractionLength(7)))
                Text(verbatim: "(\(latitude), \(longitude))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let horizontalAccuracy = (location.horizontalAccuracy ?? -1).formatted(.number.precision(.fractionLength(1)))
                Text("Acc: \(horizontalAccuracy)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                let speed = (location.speed ?? -1).formatted(.number.precision(.significantDigits(2)))
                Text("Speed: \(speed)")
                    .font(.system(.caption2, design: .monospaced))
            }
        }
        .padding(.vertical, 2)
    }
}

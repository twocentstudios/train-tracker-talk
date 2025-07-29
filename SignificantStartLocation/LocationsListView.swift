import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

@Selection
struct LocationSessionRow {
    let location: Location
    let session: Session
}

struct SectionGroup: Identifiable {
    var id: UUID { session.id }
    let session: Session
    let locations: [Location]
}

struct LocationsListView: View {
    @ObservationIgnored
    @FetchAll(
        Location
            .order { $0.timestamp.desc() }
            .join(Session.all) { $0.sessionID.eq($1.id) }
            .select {
                LocationSessionRow.Columns(
                    location: $0,
                    session: $1
                )
            },
        animation: .default
    )
    var locationRows: [LocationSessionRow]

    @State private var selectedSectionGroup: SectionGroup?

    private var sectionGroups: [SectionGroup] {
        let grouped = Dictionary(grouping: locationRows) { $0.session.id }
        return grouped.compactMapValues { rows in
            guard let firstRow = rows.first else { return nil }
            return SectionGroup(
                session: firstRow.session,
                locations: rows.map(\.location).sorted { $0.timestamp > $1.timestamp }
            )
        }
        .values
        .sorted { $0.session.date > $1.session.date }
    }

    var body: some View {
        List {
            ForEach(sectionGroups, id: \.session.id) { sectionGroup in
                Section {
                    ForEach(sectionGroup.locations) { location in
                        LocationRowView(location: location)
                    }
                } header: {
                    let headerText = sectionGroup.session.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) +
                        (sectionGroup.session.notes.map { " - \($0)" } ?? "")

                    Button {
                        selectedSectionGroup = sectionGroup
                    } label: {
                        HStack(spacing: 4) {
                            Text(headerText)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $selectedSectionGroup) { sectionGroup in
            SectionMapView(sectionGroup: sectionGroup)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ExportDatabaseView()
            }
        }
    }
}

struct LocationRowView: View {
    let location: Location

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.timestamp, format: .dateTime.hour().minute().second(.twoDigits).secondFraction(.fractional(3)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                let latitude = location.latitude.formatted(.number.precision(.fractionLength(7)))
                let longitude = location.longitude.formatted(.number.precision(.fractionLength(7)))
                Text(verbatim: "(\(latitude), \(longitude))")
                    .font(.system(.caption2, design: .monospaced))
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

struct SectionMapView: View {
    let sectionGroup: SectionGroup
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
    @State private var notes: String

    init(sectionGroup: SectionGroup) {
        self.sectionGroup = sectionGroup
        _notes = State(initialValue: sectionGroup.session.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            let coordinates = sectionGroup.locations.map { location in
                CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            }

            VStack(spacing: 0) {
                Map(initialPosition: .automatic) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.blue, lineWidth: 3)
                    }
                }

                HStack {
                    TextField("Notes", text: $notes)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        saveNotes()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(notes == (sectionGroup.session.notes ?? ""))
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle(sectionGroup.session.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
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
                    .where { $0.id.eq(sectionGroup.session.id) }
                    .update { $0.notes = notes.isEmpty ? nil : notes }
                    .execute(db)
            }
        }
    }
}

import MapKit
import SharingGRDB
import SwiftUI

struct LocationsListView: View {
    @ObservationIgnored
    @FetchAll(
        Session.all.order { $0.date.desc() },
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let notes = session.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if session.isFromColdLaunch {
                        Text("Cold Launch")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SessionDetailView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    @ObservationIgnored
    @FetchAll var locations: [Location]

    init(session: Session) {
        self.session = session
        _locations = FetchAll(
            Location
                .where { $0.sessionID.eq(session.id) }
                .order { $0.timestamp.asc() },
            animation: .default
        )
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

                    ForEach(locations) { location in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                List {
                    ForEach(locations) { location in
                        LocationRowView(location: location)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle(session.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
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

import Dependencies
import MapKit
import SharingGRDB
import SwiftUI

struct SessionsListView: View {
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
                // Status indicator
                Circle()
                    .fill(session.isComplete ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(session.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    // Train indicator
                    if session.isOnTrain {
                        Image(systemName: "tram.fill")
                            .foregroundStyle(.primary)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.2))
                            .cornerRadius(4)
                            .imageScale(.small)
                    }

                    // Cold launch indicator
                    if session.isFromColdLaunch {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
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
                    .foregroundStyle(location.speed ?? 0 >= 6.0 ? .red : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}

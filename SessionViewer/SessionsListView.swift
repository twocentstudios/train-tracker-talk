import Foundation
import GRDB
import SwiftUI

private let iso8601Formatter = ISO8601DateFormatter()

struct SessionsListView: View {
    let databaseURL: URL
    @Binding var selectedSessionID: String?
    @State private var sessions: [SessionSummary] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading sessions...")
                        .foregroundStyle(.secondary)
                }
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Failed to load sessions")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No sessions found")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("This database doesn't contain any session data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(sessions, id: \.id, selection: $selectedSessionID) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.startDate, format: .dateTime.day().month().hour().minute())
                                .font(.headline)

                            Spacer()

                            if session.isOnTrain {
                                Image(systemName: "train.side.front.car")
                                    .foregroundStyle(.blue)
                            }
                        }

                        HStack {
                            Text(session.durationFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let locationCount = session.locationCount {
                                Text("\(locationCount) locations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Sessions")
        .task {
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        error = nil

        do {
            let dbQueue = try DatabaseQueue(path: databaseURL.path)
            let loadedSessions = try await dbQueue.read { db in
                try SessionSummary.fetchAll(db)
            }

            await MainActor.run {
                sessions = loadedSessions.sorted { $0.startDate > $1.startDate }
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

struct SessionSummary: Hashable, Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date?
    let isOnTrain: Bool
    let locationCount: Int?

    var durationFormatted: String {
        guard let endDate else { return "Active" }

        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

extension SessionSummary: FetchableRecord {
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
        locationCount = row["locationCount"]
    }

    static func fetchAll(_ db: Database) throws -> [SessionSummary] {
        let sql = """
        SELECT 
            s.id,
            s.startDate,
            s.endDate,
            s.isOnTrain,
            COUNT(l.id) as locationCount
        FROM sessions s
        LEFT JOIN locations l ON s.id = l.sessionID
        GROUP BY s.id, s.startDate, s.endDate, s.isOnTrain
        ORDER BY s.startDate DESC
        """

        return try SessionSummary.fetchAll(db, sql: sql)
    }
}

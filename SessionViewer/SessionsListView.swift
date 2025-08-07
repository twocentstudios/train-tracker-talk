import Foundation
import GRDB
import SharingGRDB
import SwiftUI

private let iso8601Formatter = ISO8601DateFormatter()

struct SessionsListView: View {
    let database: any DatabaseReader
    @Binding var selectedSessionID: UUID?
    @State private var sessions: [Session] = []
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
            let loadedSessions = try await database.read { db in
                try Session.order { $0.startDate.desc() }.fetchAll(db)
            }

            await MainActor.run {
                sessions = loadedSessions
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

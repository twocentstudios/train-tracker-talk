import GRDB
import SwiftUI

struct ContentView: View {
    var document: SessionDatabase
    @State private var selectedSessionID: UUID?
    @State private var sessionsDatabase: (any DatabaseReader)?
    @State private var railwayDatabase: (any DatabaseReader)?
    @State private var databaseError: Error?
    @State private var railwayDatabaseError: Error?

    var body: some View {
        Group {
            if let databaseError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Failed to open session database")
                        .font(.headline)

                    Text(databaseError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let railwayDatabaseError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Failed to open railway database")
                        .font(.headline)

                    Text(railwayDatabaseError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let sessionsDatabase, let _ = railwayDatabase {
                NavigationSplitView {
                    SessionsListView(
                        database: sessionsDatabase,
                        selectedSessionID: $selectedSessionID
                    )
                    .frame(minWidth: 170)
                } detail: {
                    if let sessionID = selectedSessionID {
                        SessionDetailView(
                            store: SessionDetailStore(
                                database: sessionsDatabase,
                                sessionID: sessionID
                            )
                        )
                    } else {
                        Text("Select a session to view details")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Opening databases...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(document.fileURL.lastPathComponent)
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        do {
            let database = try openAppDatabase(path: document.fileURL.path)
            sessionsDatabase = database
        } catch {
            databaseError = error
            return
        }

        do {
            let database = try openRailwayDatabase()
            railwayDatabase = database
        } catch {
            railwayDatabaseError = error
        }
    }
}

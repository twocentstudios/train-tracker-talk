import GRDB
import SwiftUI

struct ContentView: View {
    var document: SessionDatabase
    @State private var selectedSessionID: UUID?
    @State private var sessionsDatabase: (any DatabaseReader)?
    @State private var databaseError: Error?

    var body: some View {
        Group {
            if let databaseError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Failed to open database")
                        .font(.headline)

                    Text(databaseError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let sessionsDatabase {
                NavigationSplitView {
                    SessionsListView(
                        database: sessionsDatabase,
                        selectedSessionID: $selectedSessionID
                    )
                } detail: {
                    if let sessionID = selectedSessionID {
                        SessionDetailView(
                            database: sessionsDatabase,
                            sessionID: sessionID
                        )
                    } else {
                        Text("Select a session to view details")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Opening database...")
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
            let database = try appDatabase(path: document.fileURL.path)
            sessionsDatabase = database
        } catch {
            databaseError = error
        }
    }
}

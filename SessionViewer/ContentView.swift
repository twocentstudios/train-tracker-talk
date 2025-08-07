import SwiftUI

struct ContentView: View {
    var document: SessionDatabase
    @State private var selectedSessionID: String?

    var body: some View {
        NavigationSplitView {
            SessionsListView(
                databaseURL: document.fileURL,
                selectedSessionID: $selectedSessionID
            )
        } detail: {
            if let sessionID = selectedSessionID {
                SessionDetailView(
                    databaseURL: document.fileURL,
                    sessionID: sessionID
                )
            } else {
                Text("Select a session to view details")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(document.fileURL.lastPathComponent)
    }
}

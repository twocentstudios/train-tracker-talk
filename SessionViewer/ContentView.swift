import SwiftUI

struct ContentView: View {
    @State private var selectedSessionID: String?

    var body: some View {
        NavigationSplitView {
            SessionsListView(selectedSessionID: $selectedSessionID)
        } detail: {
            if let sessionID = selectedSessionID {
                SessionDetailView(sessionID: sessionID)
            } else {
                Text("Select a session to view details")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("SessionViewer")
    }
}
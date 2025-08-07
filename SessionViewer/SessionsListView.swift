import SwiftUI

struct SessionsListView: View {
    @Binding var selectedSessionID: String?

    private let sampleSessions = [
        SessionPlaceholder(id: "1", name: "Session 1"),
        SessionPlaceholder(id: "2", name: "Session 2"),
        SessionPlaceholder(id: "3", name: "Session 3"),
    ]

    var body: some View {
        List(sampleSessions, id: \.id, selection: $selectedSessionID) { session in
            Text(session.name)
        }
        .navigationTitle("Sessions")
    }
}

struct SessionPlaceholder: Hashable {
    let id: String
    let name: String
}

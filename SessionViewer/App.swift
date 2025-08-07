import SwiftUI

@main
struct SessionViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: SessionDatabase.self) { config in
            ContentView(document: config.document)
        }
    }
}

import Dependencies
import SharingGRDB
import SwiftUI

@main
struct SessionViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: SessionDatabase.self) { config in
//            Talk06View(document: config.document)
            ContentView(document: config.document)
        }
    }
}

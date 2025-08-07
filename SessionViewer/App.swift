import SwiftUI

@main
struct SessionViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("SessionViewer")
                .font(.largeTitle)
                .padding()
        }
    }
}
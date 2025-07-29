import SwiftUI

struct RootView: View {
    let store: RootStore

    var body: some View {
        VStack {
            if store.authorizationStatus != .authorizedAlways {
                Button("Request Authorization") {
                    store.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
        }
        .padding()
    }
}

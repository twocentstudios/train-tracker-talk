import SwiftUI

struct RootView: View {
    let store: RootStore
    
    var body: some View {
        EventsListView(store: store)
    }
}
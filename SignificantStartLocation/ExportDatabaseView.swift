import Dependencies
import SharingGRDB
import SwiftUI

struct ShareDatabaseItem: Identifiable {
    let id = UUID()
    var url: URL?
}

struct ExportDatabaseView: View {
    @State private var shareItem: ShareDatabaseItem? = nil

    var body: some View {
        Group {
            if let shareItem {
                if let url = shareItem.url {
                    Menu {
                        ShareLink(item: url) {
                            Label("Share Database", systemImage: "square.and.arrow.up")
                        }
                        Button("Clear") {
                            self.shareItem = nil
                        }
                    } label: {
                        Label("Share Database", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                } else {
                    LabeledContent {
                        ProgressView()
                    } label: {
                        Label("Preparing Database...", systemImage: "square.3.layers.3d")
                    }
                }
            } else {
                Menu {
                    Button("Last Hour") { shareDatabase(interval: 60 * 60) }
                    Button("Last Day") { shareDatabase(interval: 24 * 60 * 60) }
                    Button("Last Week") { shareDatabase(interval: 7 * 24 * 60 * 60) }
                    Button("Last Month") { shareDatabase(interval: 30 * 24 * 60 * 60) }
                    Button("All Time") { shareDatabase(interval: nil) }
                } label: {
                    Label("Export Database", systemImage: "square.and.arrow.up")
                }
            }
        }
        .buttonStyle(.plain)
        .tint(Color(.accent))
    }

    private func shareDatabase(interval: TimeInterval?) {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.date.now) var now
        shareItem = .init(url: nil)
        Task {
            do {
                let url = try createShareDatabase(
                    database: database,
                    since: interval.map { now.addingTimeInterval(-$0) }
                )
                shareItem?.url = url
            } catch {
                print(error)
            }
        }
    }
}

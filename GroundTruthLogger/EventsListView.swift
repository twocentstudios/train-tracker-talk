import SharingGRDB
import SwiftUI

struct EventsListView: View {
    let store: RootStore
    
    @ObservationIgnored
    @FetchAll(Event.order { $0.timestamp.desc() }, animation: .default)
    var events
    
    @State private var currentTime = Date()
    @State private var editingEvent: Event?
    
    private let timer = Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text(currentTime.groundTruthFormatted)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .onReceive(timer) { _ in
                            currentTime = Date()
                        }
                    
                    Button {
                        store.createEvent()
                    } label: {
                        Text("Create Event")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(Color(.systemGray6))
                
                List {
                    ForEach(events) { event in
                        EventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingEvent = event
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteEvent(events[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Ground Truth Logger")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $editingEvent) { event in
            EventDetailView(event: event, store: store)
        }
    }
}

struct EventRow: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.timestamp.groundTruthFormatted)
                    .font(.system(.caption, design: .monospaced))
                
                if let category = event.category {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text(event.notes.isEmpty ? "---" : event.notes)
                .font(.caption2)
                .foregroundStyle(event.notes.isEmpty ? .tertiary : .primary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
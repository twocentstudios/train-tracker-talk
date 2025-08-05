import SharingGRDB
import SwiftUI

struct EventsListView: View {
    let store: RootStore

    @ObservationIgnored
    @FetchAll(Event.order { $0.timestamp.desc() }, animation: .default)
    var events

    @State private var currentTime = Date()
    @State private var editingEvent: Event?
    @State private var selectedCategory: EventCategory?

    private let timer = Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Ground Truth Logger")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    Text(currentTime.groundTruthFormatted)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .onReceive(timer) { _ in
                            currentTime = Date()
                        }

                    Picker("Category", selection: $selectedCategory) {
                        Image(systemName: "minus.circle").tag(nil as EventCategory?)
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            Image(systemName: category.systemImage)
                                .tag(category as EventCategory?)
                        }
                    }
                    .colorMultiply(selectedCategory?.color ?? .secondary)
                    .pickerStyle(.segmented)

                    Button {
                        store.createEvent(category: selectedCategory)
                    } label: {
                        Text("Create Event")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(.accent))
                }
                .padding()
                .background(.regularMaterial, in: Rectangle())
            }
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
                    HStack(spacing: 4) {
                        Image(systemName: category.systemImage)
                            .font(.caption2)
                            .foregroundStyle(category.color)
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundStyle(category.color)
                    }
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

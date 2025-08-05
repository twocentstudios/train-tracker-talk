import SwiftUI

struct EventDetailView: View {
    @State private var event: Event
    let store: RootStore
    
    @Environment(\.dismiss) private var dismiss
    
    init(event: Event, store: RootStore) {
        self._event = State(initialValue: event)
        self.store = store
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Timestamp") {
                    MillisecondDatePicker(date: $event.timestamp)
                }
                
                Section("Category") {
                    Picker("Category", selection: $event.category) {
                        Text("None").tag(nil as EventCategory?)
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category as EventCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Notes") {
                    TextEditor(text: $event.notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        store.updateEvent(event)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

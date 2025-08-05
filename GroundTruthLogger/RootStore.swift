import Foundation
import Observation
import SharingGRDB

@MainActor @Observable final class RootStore {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date) private var date

    func createEvent(category: EventCategory? = nil, notes: String = "") {
        let event = Event(
            id: uuid(),
            timestamp: date(),
            category: category,
            notes: notes
        )

        withErrorReporting {
            try database.write { db in
                try Event.insert { event }.execute(db)
            }
        }
    }

    func deleteEvent(_ event: Event) {
        withErrorReporting {
            try database.write { db in
                try Event.delete().where { $0.id == event.id }.execute(db)
            }
        }
    }

    func updateEvent(_ event: Event) {
        withErrorReporting {
            try database.write { db in
                try Event
                    .where { $0.id.eq(event.id) }
                    .update {
                        $0.timestamp = event.timestamp
                        $0.category = event.category
                        $0.notes = event.notes
                    }
                    .execute(db)
            }
        }
    }
}

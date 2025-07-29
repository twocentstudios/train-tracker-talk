import Foundation
import SharingGRDB

@Table struct Session: Hashable, Identifiable {
    let id: UUID
    var date: Date
    var notes: String?

    init(
        id: UUID,
        date: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.notes = notes
    }
}

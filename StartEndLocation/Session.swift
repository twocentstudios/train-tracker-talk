import Foundation
import SharingGRDB

@Table struct Session: Hashable, Identifiable {
    let id: UUID
    var date: Date
    var notes: String?
    var isFromColdLaunch: Bool

    init(
        id: UUID,
        date: Date,
        notes: String? = nil,
        isFromColdLaunch: Bool = false
    ) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isFromColdLaunch = isFromColdLaunch
    }
}

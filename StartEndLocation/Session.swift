import Foundation
import SharingGRDB

@Table struct Session: Hashable, Identifiable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var isFromColdLaunch: Bool
    var isOnTrain: Bool

    init(
        id: UUID,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        isFromColdLaunch: Bool = false,
        isOnTrain: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isFromColdLaunch = isFromColdLaunch
        self.isOnTrain = isOnTrain
    }
}

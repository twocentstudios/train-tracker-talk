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

extension Session {
    var isComplete: Bool {
        endDate != nil
    }

    var duration: TimeInterval? {
        guard let endDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }

    var durationFormatted: String {
        guard let duration else { return "Active" }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

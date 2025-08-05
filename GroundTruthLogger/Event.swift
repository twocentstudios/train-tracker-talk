import Foundation
import SharingGRDB

enum EventCategory: String, CaseIterable, Codable, QueryBindable, Hashable {
    case automotiveMotionActivity
    case walkingMotionActivity
    case trainDeparture
    case trainArrival
    case significantLocation

    var displayName: String {
        switch self {
        case .automotiveMotionActivity:
            "Automotive"
        case .walkingMotionActivity:
            "Walking"
        case .trainDeparture:
            "Train Departure"
        case .trainArrival:
            "Train Arrival"
        case .significantLocation:
            "Significant Location"
        }
    }
}

@Table struct Event: Hashable, Identifiable {
    let id: UUID
    var timestamp: Date
    var category: EventCategory?
    var notes: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: EventCategory? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.notes = notes
    }
}

extension Date {
    static let groundTruthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var groundTruthFormatted: String {
        Self.groundTruthFormatter.string(from: self)
    }
}

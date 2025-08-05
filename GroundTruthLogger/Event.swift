import Foundation
import SharingGRDB
import SwiftUI

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

    var systemImage: String {
        switch self {
        case .automotiveMotionActivity:
            "car.fill"
        case .walkingMotionActivity:
            "figure.walk"
        case .trainDeparture:
            "arrow.up.right"
        case .trainArrival:
            "arrow.down.right"
        case .significantLocation:
            "location.fill"
        }
    }

    var color: Color {
        switch self {
        case .automotiveMotionActivity:
            .blue
        case .walkingMotionActivity:
            .green
        case .trainDeparture:
            .orange
        case .trainArrival:
            .purple
        case .significantLocation:
            .red
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

extension FormatStyle where Self == Date.VerbatimFormatStyle {
    static var groundTruth: Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(
            format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .current,
            calendar: .current
        )
    }
}

import CoreMotion
import Foundation

enum MotionActivityConfidence: String, Codable, CaseIterable {
    case low
    case medium
    case high

    init(from cmConfidence: CMMotionActivityConfidence) {
        switch cmConfidence {
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        @unknown default:
            self = .low
        }
    }

    var cmConfidence: CMMotionActivityConfidence {
        switch self {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }
}

struct MotionActivity: Hashable, Identifiable {
    let id: UUID
    let startDate: Date
    let confidence: MotionActivityConfidence
    let stationary: Bool
    let walking: Bool
    let running: Bool
    let automotive: Bool
    let cycling: Bool
    let unknown: Bool

    init(
        id: UUID = UUID(),
        startDate: Date,
        confidence: MotionActivityConfidence,
        stationary: Bool,
        walking: Bool,
        running: Bool,
        automotive: Bool,
        cycling: Bool,
        unknown: Bool
    ) {
        self.id = id
        self.startDate = startDate
        self.confidence = confidence
        self.stationary = stationary
        self.walking = walking
        self.running = running
        self.automotive = automotive
        self.cycling = cycling
        self.unknown = unknown
    }
}

extension MotionActivity {
    init(from cmActivity: CMMotionActivity) {
        self.init(
            startDate: cmActivity.startDate,
            confidence: MotionActivityConfidence(from: cmActivity.confidence),
            stationary: cmActivity.stationary,
            walking: cmActivity.walking,
            running: cmActivity.running,
            automotive: cmActivity.automotive,
            cycling: cmActivity.cycling,
            unknown: cmActivity.unknown
        )
    }
}

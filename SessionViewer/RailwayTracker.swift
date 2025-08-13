import Foundation
import SharingGRDB

enum FocusStationPhase: Equatable, Codable, CustomDebugStringConvertible {
    case upcoming
    case approaching
    case visiting

    var title: LocalizedStringResource {
        switch self {
        case .upcoming: .init(stringLiteral: "focusStationPhase.upcoming")
        case .approaching: .init(stringLiteral: "focusStationPhase.approaching")
        case .visiting: .init(stringLiteral: "focusStationPhase.visiting")
        }
    }

    var debugDescription: String {
        switch self {
        case .upcoming: .init(stringLiteral: "Next")
        case .approaching: .init(stringLiteral: "Soon")
        case .visiting: .init(stringLiteral: "Now")
        }
    }
}

struct RailwayTrackerCandidate: Equatable {
    var railway: Railway
    var railwayDestinationStation: Station?
    var railwayDirection: RailDirection?
    var focusStation: Station?
    var focusStationPhase: FocusStationPhase?
    var laterStation: Station?
    var laterLaterStation: Station?
}

struct RailwayTrackerResult {
    let location: Location
    var instantaneousRailwayCoordinateScores: [Railway.ID: Double]
    var instantaneousRailwayCoordinates: [Railway.ID: Coordinate]
    var candidates: [RailwayTrackerCandidate]
}

actor RailwayTracker {
    private let railwayDatabase: (any DatabaseReader)?

    var railwayScores: [Railway.ID: Double] = [:]
    var railwayAscendingScores: [Railway.ID: Double] = [:]

    init(railwayDatabase: (any DatabaseReader)?) {
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) async -> RailwayTrackerResult {
        try? await Task.sleep(for: .seconds(0.01))
        return RailwayTrackerResult(
            location: input,
            instantaneousRailwayCoordinateScores: [:],
            instantaneousRailwayCoordinates: [:],
            candidates: []
        )
    }

    func reset() {
        railwayScores = [:]
        railwayAscendingScores = [:]
    }
}

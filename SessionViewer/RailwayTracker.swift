import CoreLocation
import Foundation
import SharingGRDB
import StructuredQueries
import StructuredQueriesGRDB

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

@Selection
struct RailwayCoordinateResult {
    let railwayID: String
    let lat: Double
    let lon: Double
    let coordinateID: Int64
}

actor RailwayTracker {
    private let railwayDatabase: any DatabaseReader

    var railwayScores: [Railway.ID: Double] = [:]
    var railwayAscendingScores: [Railway.ID: Double] = [:]

    init(railwayDatabase: any DatabaseReader) {
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) async -> RailwayTrackerResult {
        do {
            let (instantaneousRailwayCoordinateScores, instantaneousRailwayCoordinates) = try await railwayDatabase.read { db in
                try Self.instantaneousRailwayCoordinateScores(db: db, location: input)
            }

            return RailwayTrackerResult(
                location: input,
                instantaneousRailwayCoordinateScores: instantaneousRailwayCoordinateScores,
                instantaneousRailwayCoordinates: instantaneousRailwayCoordinates,
                candidates: []
            )
        } catch {
            // Return empty scores on error
            print(error)
            return RailwayTrackerResult(
                location: input,
                instantaneousRailwayCoordinateScores: [:],
                instantaneousRailwayCoordinates: [:],
                candidates: []
            )
        }
    }

    func reset() {
        railwayScores = [:]
        railwayAscendingScores = [:]
    }

    private static func instantaneousRailwayCoordinateScores(db: Database, location: Location) throws -> ([Railway.ID: Double], [Railway.ID: Coordinate]) {
        var instantaneousRailwayCoordinateScores = [Railway.ID: Double]()
        var instantaneousRailwayCoordinates = [Railway.ID: Coordinate]()

        let qLat = location.coordinate.latitude
        let qLon = location.coordinate.longitude
        let delta: CLLocationDegrees = 0.02 // ~5km window
        let maxLat = qLat + delta
        let minLat = qLat - delta
        let maxLon = qLon + delta
        let minLon = qLon - delta

        let results = try #sql(
            """
            WITH ranked AS (
              SELECT
                s.railway         AS railwayID,
                c.latitude        AS lat,
                c.longitude       AS lon,
                c.id              AS coordinateID,
                ROW_NUMBER() OVER (
                  PARTITION BY s.railway
                  ORDER BY
                    ((c.latitude  - \(qLat)) * (c.latitude  - \(qLat)))
                  + ((c.longitude - \(qLon)) * (c.longitude - \(qLon)))
                ) AS rn
              FROM coordinate_rtree
              JOIN \(Coordinate.self)        AS c  ON c.id = coordinate_rtree.id
              JOIN \(SegmentCoordinate.self) AS sc ON sc.coordinate = c.id
              JOIN \(Segment.self)           AS s  ON s.id = sc.segment
              WHERE
                coordinate_rtree.minLat <= \(maxLat) AND coordinate_rtree.maxLat >= \(minLat)
                AND coordinate_rtree.minLon <= \(maxLon) AND coordinate_rtree.maxLon >= \(minLon)
            )
            SELECT railwayID, lat, lon, coordinateID
            FROM ranked
            WHERE rn = 1
            """,
            as: RailwayCoordinateResult.self
        ).fetchAll(db)

        // Process results and calculate distances
        for result in results {
            let railwayID = Railway.ID(rawValue: result.railwayID)
            let dist = CLLocation(latitude: result.lat, longitude: result.lon)
                .distance(from: location.location)

            let score = linAbsNorm(dist, bestValue: 1.0, worstValue: 3000.0, exp: 5.0)
            instantaneousRailwayCoordinateScores[railwayID] = score
            instantaneousRailwayCoordinates[railwayID] = Coordinate(
                id: .init(rawValue: result.coordinateID),
                latitude: result.lat,
                longitude: result.lon
            )
        }

        return (instantaneousRailwayCoordinateScores, instantaneousRailwayCoordinates)
    }
}

/// Helpers
func linAbsNorm(_ value: Double, bestValue: Double, worstValue: Double, exp: Double = 1.0) -> Double {
    let absValue: Double = abs(value)
    let scaledValue: Double = (worstValue - absValue) / (worstValue - bestValue)
    let normValue: Double = max(0, min(scaledValue, 1))
    let superLinearValue = pow(normValue, exp)
    return superLinearValue
}

extension Optional {
    func ifNil(_ defaultValue: Wrapped) -> Wrapped {
        if let value = self {
            value
        } else {
            defaultValue
        }
    }
}

extension Double {
    func invalidOptional() -> Double? {
        if self == -1 {
            return nil
        }
        return self
    }
}

extension Location {
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

import CoreLocation
import Foundation
import SharingGRDB
import simd
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
    var instantaneousRailwayAscendingScores: [Railway.ID: Double]
    var railwayScores: [Railway.ID: Double]
    var railwayDirections: [Railway.ID: RailDirection]
    var candidates: [RailwayTrackerCandidate]
}

actor RailwayTracker {
    private let railwayDatabase: any DatabaseReader

    var railwayScores: [Railway.ID: Double] = [:]
    var railwayAscendingScores: [Railway.ID: Double] = [:]
    var railwayDirections: [Railway.ID: RailDirection] = [:]

    init(railwayDatabase: any DatabaseReader) {
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) -> RailwayTrackerResult {
        do {
            var instantaneousRailwayCoordinateScores = [Railway.ID: Double]()
            var instantaneousRailwayCoordinates = [Railway.ID: Coordinate]()
            var instantaneousRailwayAscendingScores = [Railway.ID: Double]()
            var candidates = [RailwayTrackerCandidate]()

            try railwayDatabase.read { db in
                (instantaneousRailwayCoordinateScores, instantaneousRailwayCoordinates) = try Self.instantaneousRailwayCoordinateScores(db: db, location: input)
                instantaneousRailwayAscendingScores = try Self.instantaneousRailwayAscending(db: db, location: input, railways: Array(instantaneousRailwayCoordinateScores.keys))

                let speedNorm = linAbsNorm(input.speed.ifNil(-1).invalidOptional().ifNil(0.0), bestValue: 20.0, worstValue: 2.0, exp: 0.7)

                // Add scores to the running total, where slow speeds have low weight
                for (railwayID, score) in instantaneousRailwayCoordinateScores {
                    let speedScaledScore = score * speedNorm
                    railwayScores[railwayID, default: 0] += speedScaledScore
                }

                // Add ascending scores to the running total
                for (railwayID, score) in instantaneousRailwayAscendingScores {
                    var runningScore = railwayAscendingScores[railwayID, default: 0]
                    runningScore += score
                    let minMaxScore = 10.0
                    runningScore = max(min(minMaxScore, runningScore), -minMaxScore)
                    railwayAscendingScores[railwayID] = runningScore

                    // Assign the proper railway direction
                    if let railwayRecord = try Railway.find(railwayID).fetchOne(db) {
                        let minimumScore = 2.0
                        if abs(runningScore) > minimumScore {
                            railwayDirections[railwayID] = runningScore > 0 ? railwayRecord.ascending : railwayRecord.descending
                        } else {
                            railwayDirections[railwayID] = nil
                            // TODO: clear station scores because we may have reversed directions
                        }
                    }
                }

                let totalTopCandidateRailways = 8
                let topCandidateRailwayIDs = railwayScores.sorted(using: KeyPathComparator(\.value, order: .reverse)).prefix(totalTopCandidateRailways).map(\.key)
                for railwayID in topCandidateRailwayIDs {
                    guard let railwayRecord = try Railway.find(railwayID).fetchOne(db) else { continue }
                    guard let railwayDirection = railwayDirections[railwayID] else { continue }
                    var railwayDestinationStation: Station?
                    if let destinationStationID = railwayDirection == railwayRecord.ascending ? railwayRecord.stations.last : railwayRecord.stations.first {
                        railwayDestinationStation = try Station.find(destinationStationID).fetchOne(db)
                    }

                    let candidate = RailwayTrackerCandidate(
                        railway: railwayRecord,
                        railwayDestinationStation: railwayDestinationStation,
                        railwayDirection: railwayDirection,
                        focusStation: nil,
                        focusStationPhase: nil,
                        laterStation: nil,
                        laterLaterStation: nil
                    )
                    candidates.append(candidate)
                }
            }

            return RailwayTrackerResult(
                location: input,
                instantaneousRailwayCoordinateScores: instantaneousRailwayCoordinateScores,
                instantaneousRailwayCoordinates: instantaneousRailwayCoordinates,
                instantaneousRailwayAscendingScores: instantaneousRailwayAscendingScores,
                railwayScores: railwayScores,
                railwayDirections: railwayDirections,
                candidates: candidates
            )
        } catch {
            // Return empty scores on error
            print(error)
            return RailwayTrackerResult(
                location: input,
                instantaneousRailwayCoordinateScores: [:],
                instantaneousRailwayCoordinates: [:],
                instantaneousRailwayAscendingScores: [:],
                railwayScores: railwayScores,
                railwayDirections: railwayDirections,
                candidates: []
            )
        }
    }

    func reset() {
        railwayScores = [:]
        railwayAscendingScores = [:]
        railwayDirections = [:]
    }

    @Selection
    struct RailwayCoordinateResult {
        let railwayID: String
        let lat: Double
        let lon: Double
        let coordinateID: Int64
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

    @Selection
    struct RailwayStationResult {
        let railwayID: String
        let id: String
        let latitude: Double
        let longitude: Double
        let order: Int64
    }

    private static func instantaneousRailwayAscending(db: Database, location: Location, railways: [Railway.ID]) throws -> [Railway.ID: Double] {
        guard let courseVec = location.courseUnitVector else { return [:] }
        guard let speed = location.speed, speed > 3.0 else { return [:] }
        guard !railways.isEmpty else { return [:] }

        let qLat = location.latitude
        let qLon = location.longitude

        let railwayRawIDs = railways.map(\.rawValue)
        let railwayIDsSQL = railwayRawIDs.map { "'\($0)'" }.joined(separator: ", ") // see `_SequenceExpression`

        // Get the two nearest stations per railway
        let statement = #sql(
            """
            WITH nearest AS (
              SELECT
                railway       AS railwayID,
                id,
                latitude,
                longitude,
                "order",
                ROW_NUMBER() OVER (
                  PARTITION BY railway
                  ORDER BY ((latitude - \(qLat)) * (latitude - \(qLat)) + (longitude - \(qLon)) * (longitude - \(qLon)))
                ) AS rn
              FROM \(Station.self)
              WHERE railway IN (\(raw: railwayIDsSQL))
            )
            SELECT railwayID, id, latitude, longitude, "order"
            FROM nearest
            WHERE rn <= 2
            """,
            as: RailwayStationResult.self
        )
        let results = try statement.fetchAll(db)

        // Group fetched rows by railway
        var rowsByRailway = [Railway.ID: [RailwayStationResult]]()
        for result in results {
            let rid = Railway.ID(rawValue: result.railwayID)
            rowsByRailway[rid, default: []].append(result)
        }

        // Compute ascending/descending score for each railway
        var scores = [Railway.ID: Double]()
        for railwayID in railways {
            guard let pair = rowsByRailway[railwayID], pair.count == 2 else { continue }
            let r1 = pair[0], r2 = pair[1]
            guard abs(r1.order - r2.order) == 1 else { continue }

            // Order the two stations
            let start = CLLocationCoordinate2D(
                latitude: r1.order < r2.order ? r1.latitude : r2.latitude,
                longitude: r1.order < r2.order ? r1.longitude : r2.longitude
            )
            let end = CLLocationCoordinate2D(
                latitude: r1.order < r2.order ? r2.latitude : r1.latitude,
                longitude: r1.order < r2.order ? r2.longitude : r1.longitude
            )

            // Compare heading vs. station segment
            let segVec = simd_normalize(
                CLLocationCoordinate2D.vector(lhs: start, rhs: end)
            )
            let dot = simd_dot(courseVec, segVec)
            let dotNorm = linAbsNorm(dot, bestValue: 1.0, worstValue: 0, exp: 2.0)
            let dotNormSigned = dot > 0 ? dotNorm : -dotNorm

            scores[railwayID] = dotNormSigned
        }

        return scores
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

    var courseUnitVector: simd_double2? {
        guard let course else { return nil }
        let angleRadians = (90 - course) * Double.pi / 180.0
        let x = cos(angleRadians)
        let y = sin(angleRadians)
        return simd_double2(x, y)
    }
}

extension CLLocationCoordinate2D {
    static func vector(lhs: Self, rhs: Self) -> simd_double2 {
        .init(rhs.longitude - lhs.longitude, rhs.latitude - lhs.latitude)
    }
}

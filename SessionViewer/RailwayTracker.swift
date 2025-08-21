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

struct RailwayRailDirection: Hashable {
    var railwayID: Railway.ID
    var railDirection: RailDirection
}

struct StationRailDirection: Hashable {
    var stationID: Station.ID
    var railDirection: RailDirection
}

struct StationDirectionalLocationHistory {
    // Locations within N meters from station (date asc)
    var visitingLocations: [Location] = []

    // Locations within K directional meters from station but outside N meters (date asc)
    var approachingLocations: [Location] = []

    // First location that does not fall within visiting/approaching, or same as last visiting location if it's the last station on the line
    var firstDepartureLocation: Location?
}

enum StationPhase {
    case departure
    case approaching
    case visiting
    case visited
    case passed
}

struct StationPhaseHistoryItem {
    var phase: StationPhase
    var date: Date
}

struct StationPhaseHistory {
    var items: [StationPhaseHistoryItem]
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
    var stationPhaseHistories: [StationRailDirection: StationPhaseHistory]
    var railwayScores: [Railway.ID: Double]
    var railwayDirections: [Railway.ID: RailDirection]
    var candidates: [RailwayTrackerCandidate]
}

struct FocusStation {
    var stationID: Station.ID
    var phase: FocusStationPhase
    var date: Date
}

actor RailwayTracker {
    private let railwayDatabase: any DatabaseReader

    var railwayScores: [Railway.ID: Double] = [:]
    var railwayAscendingScores: [Railway.ID: Double] = [:]
    var railwayDirections: [Railway.ID: RailDirection] = [:]

    var stationLocationHistories: [StationRailDirection: StationDirectionalLocationHistory] = [:]
    var stationPhaseHistories: [StationRailDirection: StationPhaseHistory] = [:]
    var railwayRailDirectionFocusStations: [RailwayRailDirection: FocusStation] = [:]

    // TODO: Set these values and use this to improve calculations
    // `Location`s not within any Railway's Station's `visiting` or `approaching` bounds.
    // Used to differentiate local from express trains penalizing any railway with locations indicating stopping between stations.
    var orphanedRailwayRailDirectionLocations: [RailwayRailDirection: [Location]] = [:]

    init(railwayDatabase: any DatabaseReader) {
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) -> RailwayTrackerResult {
        do {
            var instantaneousRailwayCoordinateScores = [Railway.ID: Double]()
            var instantaneousRailwayCoordinates = [Railway.ID: Coordinate]()
            var instantaneousRailwayAscendingScores = [Railway.ID: Double]()
            var candidates = [RailwayTrackerCandidate]()

            // TODO: consider caching full railways
            // TODO: consider passing full railways list as railwayRailDirections into helper funcs instead of refetching from db
            // TODO: consider breaking up database reads
            try railwayDatabase.read { db in
                (instantaneousRailwayCoordinateScores, instantaneousRailwayCoordinates) = try Self.instantaneousRailwayCoordinateScores(db: db, location: input)
                instantaneousRailwayAscendingScores = try Self.instantaneousRailwayAscending(db: db, location: input, railways: Array(instantaneousRailwayCoordinateScores.keys))

                let speedNorm = linAbsNorm(input.speed.ifNil(-1).invalidOptional().ifNil(0.0), bestValue: 20.0, worstValue: 2.0, exp: 0.7)

                // Add scores to the running total, where slow speeds have low weight
                for (railwayID, score) in instantaneousRailwayCoordinateScores {
                    let speedScaledScore = score * speedNorm
                    railwayScores[railwayID, default: 0] += speedScaledScore
                }

                // Add ascending scores to the running total (clipped to `abs(10)`)
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

                let topCandidateRailwayRailDirections: [RailwayRailDirection] = topCandidateRailwayIDs.compactMap { railwayID in
                    guard let railwayDirection = railwayDirections[railwayID] else { return nil }
                    return RailwayRailDirection(railwayID: railwayID, railDirection: railwayDirection)
                }

                try Self.addLocationToStationLocationHistories(
                    db: db,
                    location: input,
                    railwayRailDirections: topCandidateRailwayRailDirections,
                    stationLocationHistories: &stationLocationHistories
                )

                try Self.updateStationPhaseHistory(
                    db: db,
                    now: input.timestamp,
                    railwayRailDirections: topCandidateRailwayRailDirections,
                    stationLocationHistories: stationLocationHistories,
                    stationPhaseHistories: &stationPhaseHistories
                )

                try Self.updateFocusStation(
                    db: db,
                    railwayRailDirections: topCandidateRailwayRailDirections,
                    stationPhaseHistories: stationPhaseHistories,
                    railwayRailDirectionFocusStations: &railwayRailDirectionFocusStations
                )

                for railwayRailDirection in topCandidateRailwayRailDirections {
                    guard let railwayRecord = try Railway.find(railwayRailDirection.railwayID).fetchOne(db) else { continue }
                    let railwayDirection = railwayRailDirection.railDirection

                    let directionalStationIDs = railwayDirection == railwayRecord.ascending ? railwayRecord.stations : railwayRecord.stations.reversed()

                    guard let destinationStationID = directionalStationIDs.last else { assertionFailure(); continue }
                    let railwayDestinationStation = try Station.find(destinationStationID).fetchOne(db)

                    guard let focusStation = railwayRailDirectionFocusStations[railwayRailDirection] else { continue }
                    guard let focusStationRecord = try Station.find(focusStation.stationID).fetchOne(db) else { assertionFailure(); continue }
                    guard let focusStationIndex = directionalStationIDs.firstIndex(of: focusStation.stationID) else { assertionFailure(); continue }
                    let laterStationIndex = focusStationIndex + 1
                    let laterLaterStationIndex = laterStationIndex + 1

                    var laterStation: Station?
                    if let laterStationID = directionalStationIDs[safe: laterStationIndex],
                       let s = try Station.find(laterStationID).fetchOne(db)
                    {
                        laterStation = s
                    }
                    var laterLaterStation: Station?
                    if let laterLaterStationID = directionalStationIDs[safe: laterLaterStationIndex],
                       let s = try Station.find(laterLaterStationID).fetchOne(db)
                    {
                        laterLaterStation = s
                    }

                    let candidate = RailwayTrackerCandidate(
                        railway: railwayRecord,
                        railwayDestinationStation: railwayDestinationStation,
                        railwayDirection: railwayDirection,
                        focusStation: focusStationRecord,
                        focusStationPhase: focusStation.phase,
                        laterStation: laterStation,
                        laterLaterStation: laterLaterStation
                    )
                    candidates.append(candidate)
                }
            }

            return RailwayTrackerResult(
                location: input,
                instantaneousRailwayCoordinateScores: instantaneousRailwayCoordinateScores,
                instantaneousRailwayCoordinates: instantaneousRailwayCoordinates,
                instantaneousRailwayAscendingScores: instantaneousRailwayAscendingScores,
                stationPhaseHistories: stationPhaseHistories,
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
                stationPhaseHistories: stationPhaseHistories,
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

    /// Returns a tuple of scores (0.0 ... 1.0) for each Railway within 5km of `location` and the closest `Coordinate` on the path of each `Railway` to `location`
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

        // The closest Coordinate for each Railway within N km of `location`
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

    /// Returns an "ascending" score (-1.0 ... 1.0) for each of `railways` for `location`.
    /// -1.0 is fully "descending" and 1.0 is fully "ascending" as defined by the `Railway` data.
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

    private static func addLocationToStationLocationHistories(
        db: Database,
        location: Location,
        railwayRailDirections: [RailwayRailDirection],
        stationLocationHistories: inout [StationRailDirection: StationDirectionalLocationHistory]
    ) throws {
        guard let courseUnitVector = location.courseUnitVector else {
            // TODO: how to handle locations with no course?
            // TODO: handle dot as optional - not required for dist <= visitingDistanceConst case
            return
        }

        // TODO: tweak these constants
        let visitingDistanceConst: CLLocationDistance = 200
        let approachingDistanceConst: CLLocationDistance = 500

        for railwayRailDirection in railwayRailDirections {
            guard let railway = try Railway.find(railwayRailDirection.railwayID).fetchOne(db) else { throw NotFound() }
            let isAscending = railwayRailDirection.railDirection == railway.ascending
            let directionalStations = try Station
                .where { $0.id.in(railway.stations) }
                .order(by: {
                    if isAscending {
                        $0.order.asc()
                    } else {
                        $0.order.desc()
                    }
                })
                .fetchAll(db)

            // The `location` is placed in at most one station's `visiting` or `approaching` histories per railway.
            // A `location` can be repeated amongst many stations' `firstDepartureLocation`.
            // Stations earlier in the direction of travel have priority in "claiming" a `location` in the case a `visiting` boundary of the earlier station overlaps a `approaching` boundary in the later station.
            var hasPlacedLocationInRailway = false
            var potentialDepartureStation: (Station.ID, CLLocationDistance)? = nil
            for station in directionalStations {
                let stationRailDirection = StationRailDirection(stationID: station.id, railDirection: railwayRailDirection.railDirection)
                guard !hasPlacedLocationInRailway else { continue }

                // Calculate distance and dot product from location to station
                let dist = station.location.distance(from: location.location)
                let dot = simd_dot(
                    simd_normalize(CLLocationCoordinate2D.vector(lhs: location.coordinate, rhs: station.coordinate)),
                    courseUnitVector
                )

                if dist <= visitingDistanceConst {
                    // location is within visiting distance
                    stationLocationHistories[stationRailDirection, default: .init()].visitingLocations.append(location)
                    hasPlacedLocationInRailway = true

                    // If this is the last station in the railway, always set its firstDepartureLocation to mark it complete
                    if station.id == directionalStations.last?.id {
                        stationLocationHistories[stationRailDirection]?.firstDepartureLocation = location
                    }
                } else if dist <= approachingDistanceConst, dot > 0 {
                    // location is within approaching distance and facing station in travel direction
                    stationLocationHistories[stationRailDirection, default: .init()].approachingLocations.append(location)
                    hasPlacedLocationInRailway = true
                } else if dot < 0 {
                    // Always set `firstDepartureLocation` for any stations "passed" and "in progress" but not yet completed
                    if let stationLocationHistory = stationLocationHistories[stationRailDirection],
                       stationLocationHistory.firstDepartureLocation == nil,
                       !stationLocationHistory.visitingLocations.isEmpty,
                       !stationLocationHistory.approachingLocations.isEmpty
                    {
                        stationLocationHistories[stationRailDirection]?.firstDepartureLocation = location
                    } else if let bestCandidate = potentialDepartureStation, dist < bestCandidate.1 {
                        potentialDepartureStation = (station.id, dist)
                    } else if potentialDepartureStation == nil {
                        potentialDepartureStation = (station.id, dist)
                    }
                }
            }

            // TODO: add orphanedRailwayRailDirectionLocations: [RailwayRailDirection: [Location]] class-level store to add locations that are not hasPlacedLocationInRailway
            // TODO: use these during railway score calculation - railway score should decrease if speed < 1 locations exist between stations (meaning an express train on the same line as a local will be lowered when riding the local)

            // In the case the railway has no stations with departures, mark the departure station
            let isStationDeparturesHistoriesEmpty = directionalStations
                .compactMap { stationLocationHistories[.init(stationID: $0.id, railDirection: railwayRailDirection.railDirection)]?.firstDepartureLocation }
                .isEmpty
            if isStationDeparturesHistoriesEmpty, let potentialDepartureStation {
                stationLocationHistories[.init(stationID: potentialDepartureStation.0, railDirection: railwayRailDirection.railDirection)] = .init(firstDepartureLocation: location)
            }
        }
    }

    /// Update the phase history for each Station based on the stationLocationHistories
    private static func updateStationPhaseHistory(
        db: Database,
        now: Date,
        railwayRailDirections: [RailwayRailDirection],
        stationLocationHistories: [StationRailDirection: StationDirectionalLocationHistory],
        stationPhaseHistories: inout [StationRailDirection: StationPhaseHistory]
    ) throws {
        let stationVisitedDwellTimeConst: TimeInterval = 20
        for railwayRailDirection in railwayRailDirections {
            guard let railway = try Railway.find(railwayRailDirection.railwayID).fetchOne(db) else { throw NotFound() }
            let directionalStationIDs = railwayRailDirection.railDirection == railway.ascending ? railway.stations : railway.stations.reversed()
            for stationID in directionalStationIDs {
                let stationRailDirection = StationRailDirection(stationID: stationID, railDirection: railwayRailDirection.railDirection)
                guard let stationLocationHistory = stationLocationHistories[stationRailDirection] else { continue }
                let proposedStationPhaseHistoryItem: StationPhaseHistoryItem?
                if stationLocationHistory.visitingLocations.isEmpty,
                   stationLocationHistory.approachingLocations.isEmpty,
                   stationLocationHistory.firstDepartureLocation != nil
                {
                    proposedStationPhaseHistoryItem = .init(phase: .departure, date: now)
                } else if stationLocationHistory.visitingLocations.isEmpty,
                          !stationLocationHistory.approachingLocations.isEmpty,
                          stationLocationHistory.firstDepartureLocation == nil
                {
                    proposedStationPhaseHistoryItem = .init(phase: .approaching, date: now)
                } else if !stationLocationHistory.visitingLocations.isEmpty,
                          stationLocationHistory.firstDepartureLocation == nil
                {
                    proposedStationPhaseHistoryItem = .init(phase: .visiting, date: now)
                } else if let firstVisitingLocation = stationLocationHistory.visitingLocations.first,
                          let firstDepartureLocation = stationLocationHistory.firstDepartureLocation
                {
                    if stationID == directionalStationIDs.last {
                        // Last station on a line will always be visited
                        proposedStationPhaseHistoryItem = .init(phase: .visited, date: now)
                    } else if firstDepartureLocation.timestamp.timeIntervalSince(firstVisitingLocation.timestamp) > stationVisitedDwellTimeConst {
                        proposedStationPhaseHistoryItem = .init(phase: .visited, date: now)
                    } else {
                        proposedStationPhaseHistoryItem = .init(phase: .passed, date: now)
                    }
                } else {
                    proposedStationPhaseHistoryItem = nil
                    reportIssue("unexpected stationLocationHistory: \(stationLocationHistory)")
                }

                guard let proposedStationPhaseHistoryItem else { continue }
                let latestStationHistoryItem = stationPhaseHistories[stationRailDirection]?.items.last
                if let latestStationHistoryItem,
                   latestStationHistoryItem.date > proposedStationPhaseHistoryItem.date
                {
                    // Ensure the new item is not somehow earlier than the old one
                    assertionFailure("unexpected condition: \(latestStationHistoryItem) is later than \(proposedStationPhaseHistoryItem)")
                    continue
                }

                // Handle the possible state transition
                let validatedStationPhaseHistoryItem: StationPhaseHistoryItem?
                switch latestStationHistoryItem?.phase {
                case .none:
                    // If phase history is empty, always set the proposed item
                    validatedStationPhaseHistoryItem = proposedStationPhaseHistoryItem
                case .some(.departure):
                    switch proposedStationPhaseHistoryItem.phase {
                    case .departure:
                        // Skip duplicate
                        validatedStationPhaseHistoryItem = nil
                    default:
                        assertionFailure("departure phase should always be terminal phase; instead got \(proposedStationPhaseHistoryItem)")
                        validatedStationPhaseHistoryItem = nil
                    }
                case .some(.approaching):
                    switch proposedStationPhaseHistoryItem.phase {
                    case .approaching:
                        // Skip duplicate
                        validatedStationPhaseHistoryItem = nil
                    case .departure:
                        assertionFailure("invalid transition: approaching -> departure")
                        validatedStationPhaseHistoryItem = nil
                    default:
                        validatedStationPhaseHistoryItem = proposedStationPhaseHistoryItem
                    }
                case .some(.visiting):
                    switch proposedStationPhaseHistoryItem.phase {
                    case .visiting:
                        // Skip duplicate
                        validatedStationPhaseHistoryItem = nil
                    case .approaching, .departure:
                        assertionFailure("invalid transition: visiting -> \(proposedStationPhaseHistoryItem.phase)")
                        validatedStationPhaseHistoryItem = nil
                    default:
                        validatedStationPhaseHistoryItem = proposedStationPhaseHistoryItem
                    }
                case .some(.visited):
                    switch proposedStationPhaseHistoryItem.phase {
                    case .visited:
                        // Skip duplicate
                        validatedStationPhaseHistoryItem = nil
                    default:
                        // terminal state
                        assertionFailure("invalid transition: visited -> \(proposedStationPhaseHistoryItem.phase)")
                        validatedStationPhaseHistoryItem = nil
                    }
                case .some(.passed):
                    switch proposedStationPhaseHistoryItem.phase {
                    case .passed:
                        // Skip duplicate
                        validatedStationPhaseHistoryItem = nil
                    default:
                        // terminal state
                        assertionFailure("invalid transition: passed -> \(proposedStationPhaseHistoryItem.phase)")
                        validatedStationPhaseHistoryItem = nil
                    }
                }

                if let validatedStationPhaseHistoryItem {
                    // Append the new valid history item
                    stationPhaseHistories[stationRailDirection, default: .init(items: [])].items.append(validatedStationPhaseHistoryItem)
                }
            }
        }
    }

    private static func updateFocusStation(
        db: Database,
        railwayRailDirections: [RailwayRailDirection],
        stationPhaseHistories: [StationRailDirection: StationPhaseHistory],
        railwayRailDirectionFocusStations: inout [RailwayRailDirection: FocusStation]
    ) throws {
        for railwayRailDirection in railwayRailDirections {
            guard let railway = try Railway.find(railwayRailDirection.railwayID).fetchOne(db) else { throw NotFound() }
            let directionalStationIDs = railwayRailDirection.railDirection == railway.ascending ? railway.stations : railway.stations.reversed()
            let directionalLatestStationPhaseHistoryItems: [StationPhaseHistoryItem?] = directionalStationIDs
                .map { StationRailDirection(stationID: $0, railDirection: railwayRailDirection.railDirection) }
                .map { stationPhaseHistories[$0, default: .init(items: [])] }
                .map(\.items.last)

            var proposedFocusStation: FocusStation? = nil
            for (index, phaseHistoryItem) in directionalLatestStationPhaseHistoryItems.enumerated() {
                // Ignore stations with no history
                guard let phaseHistoryItem else { continue }

                guard let stationID = directionalStationIDs[safe: index] else { assertionFailure(); continue }

                // We'll often need to know the next station
                let nextStationID = directionalStationIDs[safe: index + 1]

                // Set the proposed FocusStation assuming this station is the last one with a valid PhaseHistoryItem
                // The proposed FocusStation will be overwritten until we've reached the actual last one
                switch phaseHistoryItem.phase {
                case .departure:
                    if let nextStationID {
                        proposedFocusStation = FocusStation(stationID: nextStationID, phase: .upcoming, date: phaseHistoryItem.date)
                    } else {
                        // Departure station is final (Ambiguous case)
                        proposedFocusStation = FocusStation(stationID: stationID, phase: .visiting, date: phaseHistoryItem.date)
                    }
                case .approaching:
                    proposedFocusStation = FocusStation(stationID: stationID, phase: .approaching, date: phaseHistoryItem.date)
                case .visiting:
                    proposedFocusStation = FocusStation(stationID: stationID, phase: .visiting, date: phaseHistoryItem.date)
                case .visited,
                     .passed:
                    if let nextStationID {
                        proposedFocusStation = FocusStation(stationID: nextStationID, phase: .upcoming, date: phaseHistoryItem.date)
                    } else {
                        // Visited station is final
                        proposedFocusStation = FocusStation(stationID: stationID, phase: .visiting, date: phaseHistoryItem.date)
                    }
                }
            }
            guard let proposedFocusStation else {
                // Railway has no station phase history data
                continue
            }
            railwayRailDirectionFocusStations[railwayRailDirection] = proposedFocusStation
        }
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

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

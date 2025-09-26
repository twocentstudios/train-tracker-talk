import Foundation
import GRDB
import IssueReporting
import OSLog

/*
 Railway Database Schema:

 railway: id(TEXT PK), title(TEXT), stations(TEXT), color(TEXT), ascending(TEXT), descending(TEXT)
 station: id(TEXT PK), railway(TEXT FK), title(TEXT), latitude(DOUBLE), longitude(DOUBLE), order(INT)
 segment: id(INT PK AUTO), railway(TEXT FK), underground(BOOL), order(INT)
 coordinate: id(INT PK AUTO), latitude(DOUBLE), longitude(DOUBLE) UNIQUE(lat,lon)
 segmentCoordinate: segment(INT FK), order(INT), coordinate(INT FK) PK(segment,order)

 Indexes:
 - station_on_latitude ON station(latitude)
 - station_on_longitude ON station(longitude)
 - coordinate_on_latitude ON coordinate(latitude)
 - coordinate_on_longitude ON coordinate(longitude)
 - station_rtree: R-Tree spatial index (id, minLat, maxLat, minLon, maxLon)
 - coordinate_rtree: R-Tree spatial index (id, minLat, maxLat, minLon, maxLon)
 */

private let logger = Logger(subsystem: "com.twocentstudios.train-tracker-talk.SessionViewer", category: "RailwayDatabase")

func openRailwayDatabase() throws -> any DatabaseReader {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    configuration.readonly = true

    #if DEBUG
        configuration.prepareDatabase { db in
            db.trace(options: .profile) {
                logger.debug("\($0.expandedDescription)")
            }
        }
    #endif

    reportIssue("NOTE TO DEVELOPER: real railway data is not included in this repo due to licensing issues. `railway-template.sqlite` is included so the project will run. But the algorithm will not return results.")

    guard let databaseURL = Bundle.main.url(forResource: "railway-template", withExtension: "sqlite") else {
        throw DatabaseNotFoundError()
    }

    logger.info("Opening read-only railway database at \(databaseURL.path)")
    let database = try DatabaseQueue(path: databaseURL.path, configuration: configuration)

    return database
}

struct DatabaseNotFoundError: Error {
    var localizedDescription: String {
        "Railway database file (railway-template.sqlite) not found in app bundle."
    }
}

import Foundation
import GRDB
import OSLog

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

    guard let databaseURL = Bundle.main.url(forResource: "railway", withExtension: "sqlite") else {
        throw DatabaseNotFoundError()
    }

    logger.info("Opening read-only railway database at \(databaseURL.path)")
    let database = try DatabaseQueue(path: databaseURL.path, configuration: configuration)

    return database
}

struct DatabaseNotFoundError: Error {
    var localizedDescription: String {
        "Railway database file (railway.sqlite) not found in app bundle."
    }
}

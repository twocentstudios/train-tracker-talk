import Foundation
import GRDB
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "com.twocentstudios.train-tracker-talk.SignificantChange", category: "Database")

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    #if DEBUG
        configuration.prepareDatabase { db in
            db.trace(options: .profile) {
                if context == .preview {
                    print("\($0.expandedDescription)")
                } else {
                    logger.debug("\($0.expandedDescription)")
                }
            }
        }
    #endif

    let database: any DatabaseWriter
    if context == .live {
        let path = URL.documentsDirectory.appending(component: "significant-change-db.sqlite").path()
        logger.info("Opening database at \(path)")
        database = try DatabasePool(path: path, configuration: configuration)
    } else if context == .test {
        let path = URL.temporaryDirectory.appending(component: "\(UUID().uuidString)-db.sqlite").path()
        database = try DatabasePool(path: path, configuration: configuration)
    } else {
        database = try DatabaseQueue(configuration: configuration)
    }

    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create `locations` table") { db in
        try db.execute(sql: """
        CREATE TABLE locations (
            id TEXT PRIMARY KEY NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL,
            timestamp TEXT NOT NULL,
            horizontalAccuracy REAL,
            verticalAccuracy REAL,
            course REAL,
            speed REAL,
            isFromColdLaunch INTEGER NOT NULL DEFAULT 0
        )
        """)

        try db.execute(sql: """
        CREATE INDEX idx_location_timestamp ON locations(timestamp)
        """)
    }

    try migrator.migrate(database)
    return database
}

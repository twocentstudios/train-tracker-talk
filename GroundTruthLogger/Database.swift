import Foundation
import GRDB
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "com.twocentstudios.train-tracker-talk.GroundTruthLogger", category: "Database")

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
        let path = URL.documentsDirectory.appending(component: "ground-truth-logger-db.sqlite").path()
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

    migrator.registerMigration("Create `events` table") { db in
        try db.execute(sql: """
        CREATE TABLE events (
            id TEXT PRIMARY KEY NOT NULL,
            timestamp TEXT NOT NULL,
            category TEXT,
            notes TEXT NOT NULL DEFAULT ''
        )
        """)

        try db.execute(sql: """
        CREATE INDEX idx_event_timestamp ON events(timestamp)
        """)
    }

    try migrator.migrate(database)
    return database
}
import Foundation
import GRDB
import OSLog
import SharingGRDB

private let logger = Logger(subsystem: "com.twocentstudios.train-tracker-talk.SignificantStartLocation", category: "Database")

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

    migrator.registerMigration("Create `sessions` table") { db in
        try db.execute(sql: """
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY NOT NULL,
            startDate TEXT NOT NULL,
            endDate TEXT,
            notes TEXT,
            isFromColdLaunch INTEGER NOT NULL DEFAULT 0,
            isOnTrain INTEGER NOT NULL DEFAULT 0
        ) STRICT
        """)

        try db.execute(sql: """
        CREATE INDEX idx_session_startDate ON sessions(startDate)
        """)

        try db.execute(sql: """
        CREATE INDEX idx_session_endDate ON sessions(endDate)
        """)
    }

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
            sessionID TEXT NOT NULL,

            FOREIGN KEY(sessionID) REFERENCES sessions(id) ON DELETE CASCADE
        ) STRICT
        """)

        try db.execute(sql: """
        CREATE INDEX idx_location_timestamp ON locations(timestamp)
        """)

        try db.execute(sql: """
        CREATE INDEX idx_location_sessionID ON locations(sessionID)
        """)
    }

    migrator.registerMigration("Create `motionActivities` table") { db in
        try db.execute(sql: """
        CREATE TABLE motionActivities (
            id TEXT PRIMARY KEY NOT NULL,
            startDate TEXT NOT NULL,
            confidence TEXT NOT NULL,
            stationary INTEGER NOT NULL,
            walking INTEGER NOT NULL,
            running INTEGER NOT NULL,
            automotive INTEGER NOT NULL,
            cycling INTEGER NOT NULL,
            unknown INTEGER NOT NULL,
            sessionID TEXT,

            FOREIGN KEY(sessionID) REFERENCES sessions(id) ON DELETE CASCADE
        ) STRICT
        """)

        try db.execute(sql: """
        CREATE INDEX idx_motionActivity_startDate ON motionActivities(startDate)
        """)

        try db.execute(sql: """
        CREATE INDEX idx_motionActivity_sessionID ON motionActivities(sessionID)
        """)
    }

    try migrator.migrate(database)
    return database
}

func createShareDatabase(database: any DatabaseReader, since startDate: Date?) throws -> URL {
    let fileName = UUID().uuidString.prefix(6) + "_" + Date().formatted(.iso8601)
    let url = URL.temporaryDirectory
        .appending(component: fileName)
        .appendingPathExtension("sqlite")

    // Create an empty database at the target URL
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    configuration.prepareDatabase { db in
        #if DEBUG && false
            db.trace(options: .profile) {
                print($0.expandedDescription)
            }
        #endif
    }
    let shareDB = try DatabaseQueue(path: url.path, configuration: configuration)

    try database.backup(to: shareDB)

    // If a startDate is provided, remove old records from the copied database
    if let startDate {
        try shareDB.write { db in
            try db.execute(sql: "DELETE FROM locations WHERE timestamp < ?", arguments: [startDate])
        }
        try shareDB.vacuum()
    }
    try shareDB.writeWithoutTransaction { db in
        try db.execute(sql: "PRAGMA journal_mode=DELETE;")
    }

    try shareDB.close()

    return url
}

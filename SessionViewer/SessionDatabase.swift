import Foundation
import GRDB
import OSLog
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class SessionDatabase: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.database, .sqlite] }

    let fileURL: URL

    init(configuration: ReadConfiguration) throws {
        // Create a temporary file from the contents
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        try data.write(to: tempURL)
        fileURL = tempURL
    }

    func snapshot(contentType: UTType) throws -> URL {
        fileURL
    }

    func fileWrapper(snapshot: URL, configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: snapshot, options: .withoutMapping)
    }
}

extension UTType {
    static var sqlite: UTType {
        UTType(filenameExtension: "sqlite") ?? .database
    }
}

private let logger = Logger(subsystem: "com.twocentstudios.train-tracker-talk.SessionViewer", category: "Database")

func appDatabase(path: String) throws -> any DatabaseReader {
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

    logger.info("Opening read-only database at \(path)")
    let database = try DatabaseQueue(path: path, configuration: configuration)

    return database
}

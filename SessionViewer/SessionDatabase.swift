import Foundation
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

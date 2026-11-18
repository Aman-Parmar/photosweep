import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper so the CSV cleanup report can leave the app
/// through the system export sheet. The document holds text only -
/// no photo bytes, no library identifiers.
struct CleanupReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        csv = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csv.utf8))
    }
}

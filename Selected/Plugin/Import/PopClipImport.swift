import Foundation

final class PopClipImport: Identifiable {
    let id = UUID()
    let directory: URL
    let sourceName: String
    var plugin: Plugin?
    var issues: [String] = []
    var notes: [String] = []

    init(sourceName: String) throws {
        self.sourceName = sourceName
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Selected-PopClip-" + id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

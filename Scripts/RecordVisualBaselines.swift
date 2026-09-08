import AppKit

// swiftc Tests/Support/PixelDigest.swift Scripts/RecordVisualBaselines.swift -o /tmp/record-visual-baselines
// Export and review XCTest attachments before running: /tmp/record-visual-baselines <attachments-directory> <output-json>
@main
enum RecordVisualBaselines {
    private struct ExportedTest: Decodable {
        struct Attachment: Decodable {
            let suggestedHumanReadableName: String
            let exportedFileName: String
        }
        let attachments: [Attachment]
    }

    private struct Baselines: Encodable {
        let environment: String
        let images: [String: PixelDigest]
    }

    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            print("Usage: record-visual-baselines <attachments-directory> <output-json>")
            exit(2)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let manifest = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let tests = try JSONDecoder().decode([ExportedTest].self, from: manifest)
        var images: [String: PixelDigest] = [:]
        for attachment in tests.flatMap(\.attachments) {
            let name = attachment.suggestedHumanReadableName.components(separatedBy: "_0_")[0]
            guard name.hasPrefix("application-") || name.hasPrefix("clipboard-") else { continue }
            let data = try Data(contentsOf: directory.appendingPathComponent(attachment.exportedFileName))
            guard let image = NSBitmapImageRep(data: data)?.cgImage else { throw CocoaError(.fileReadCorruptFile) }
            images[name] = PixelDigest(image: image)
        }
        guard !images.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
        let baselines = Baselines(environment: "Recorded on \(ProcessInfo.processInfo.operatingSystemVersionString); English/US test scheme",
                                  images: images)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(baselines).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
        print("Recorded \(images.count) visual baselines")
    }
}

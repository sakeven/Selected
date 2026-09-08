import AppKit
import XCTest

private struct VisualSnapshotBaselines: Decodable {
    let environment: String
    let images: [String: PixelDigest]
}

extension XCTestCase {
    @MainActor
    func assertSnapshot(_ bitmap: NSBitmapImageRep, named name: String,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "VisualSnapshotBaselines", withExtension: "json"),
                                "Missing checked-in snapshot baselines", file: file, line: line)
        let baselines = try JSONDecoder().decode(VisualSnapshotBaselines.self, from: Data(contentsOf: url))
        let expected = try XCTUnwrap(baselines.images[name], "Missing snapshot: \(name)", file: file, line: line)
        let actual = PixelDigest(image: try XCTUnwrap(bitmap.cgImage, file: file, line: line))
        XCTAssertEqual(actual, expected,
                       "Snapshot changed: \(name). Baseline: \(baselines.environment). Current: \(ProcessInfo.processInfo.operatingSystemVersionString). Review the attached image before updating the baseline.",
                       file: file, line: line)
    }
}

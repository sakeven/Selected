import AppKit
import XCTest
@testable import Selected

@MainActor
final class ClipboardRestoreTests: XCTestCase {
    func testRestoresEveryRepresentationBeforeCompleting() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("old clipboard value", forType: .string)
        let text = Data("复制内容".utf8)
        let html = Data("<b>复制内容</b>".utf8)
        let item = try makeClipboardFixture(representations: [(.string, text), (.html, html)])
        item.numberOfCopies = 3
        item.lastCopiedAt = Date(timeIntervalSince1970: 0)
        let startedAt = Date()
        var completionCount = 0

        ClipService(pasteboard: pasteboard).restore(item) {
            completionCount += 1
            XCTAssertEqual(pasteboard.data(forType: .string), text)
            XCTAssertEqual(pasteboard.data(forType: .html), html)
            XCTAssertEqual(item.numberOfCopies, 4)
            XCTAssertGreaterThanOrEqual(item.lastCopiedAt ?? .distantPast, startedAt)
        }

        XCTAssertEqual(completionCount, 1)
    }
}

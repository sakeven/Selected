import AppKit
import XCTest
@testable import Selected

final class WindowGeometryTests: XCTestCase {
    func testCenteredWindowsUseActualSizeAndScreenOrigin() {
        let screen = NSRect(x: -1440, y: 100, width: 1440, height: 900)
        let frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        XCTAssertEqual(WindowPositionStrategy.centerScreen.origin(windowFrame: frame, requestedSize: .zero, screenFrame: screen), NSPoint(x: -920, y: 450))
        XCTAssertEqual(WindowPositionStrategy.centerScreenOffset(0.75).origin(windowFrame: frame, requestedSize: .zero, screenFrame: screen), NSPoint(x: -920, y: 625))
        XCTAssertEqual(WindowPositionStrategy.centerScreen.origin(windowFrame: .zero, requestedSize: frame.size, screenFrame: screen), NSPoint(x: -920, y: 450))
    }

    func testNearPointKeepsItsGapAndFlipsBelowTheTopEdge() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        let cases: [(NSPoint, NSPoint)] = [
            (.init(x: 500, y: 400), .init(x: 400, y: 418)),
            (.init(x: 2, y: 2), .init(x: 0, y: 20)),
            (.init(x: 998, y: 798), .init(x: 800, y: 680)),
            (.init(x: 500, y: 682), .init(x: 400, y: 700)),
            (.init(x: 500, y: 683), .init(x: 400, y: 565))
        ]
        for (point, origin) in cases {
            XCTAssertEqual(WindowPositionStrategy.nearPoint(point).origin(windowFrame: frame, requestedSize: .zero, screenFrame: screen), origin)
        }
    }

    func testRestoredPositionMapsRelativeCenterAcrossDisplays() throws {
        let originalScreen = NSRect(x: -1000, y: 100, width: 1000, height: 800)
        let frame = NSRect(x: -850, y: 200, width: 200, height: 200)
        let saved = WindowPositionManager.Saved(frame: frame, screenFrame: originalScreen)
        XCTAssertEqual(saved.centerRX, 0.25)
        XCTAssertEqual(saved.centerRY, 0.25)
        XCTAssertEqual(saved.frame(in: originalScreen), frame)
        let decoded = try JSONDecoder().decode(WindowPositionManager.Saved.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.frame(in: NSRect(x: 1000, y: -200, width: 1600, height: 1000)), NSRect(x: 1300, y: -50, width: 200, height: 200))
    }

    func testRestoredPositionClampsToVisibleEdges() {
        let screen = NSRect(x: 100, y: 50, width: 800, height: 600)
        let low = WindowPositionManager.Saved(sizeW: 200, sizeH: 100, centerRX: -0.2, centerRY: -0.2)
        let high = WindowPositionManager.Saved(sizeW: 200, sizeH: 100, centerRX: 1.2, centerRY: 1.2)
        XCTAssertEqual(low.frame(in: screen), NSRect(x: 100, y: 50, width: 200, height: 100))
        XCTAssertEqual(high.frame(in: screen), NSRect(x: 700, y: 550, width: 200, height: 100))
    }

    func testCloseModesKeepOriginalAndExpandedBoundaries() {
        let frame = NSRect(x: 200, y: 200, width: 200, height: 100)
        for point in [NSPoint(x: 200, y: 200), NSPoint(x: 300, y: 250)] {
            XCTAssertFalse(CloseWindowMode.original.shouldClose(frame: frame, mouseLocation: point))
            XCTAssertFalse(CloseWindowMode.expanded.shouldClose(frame: frame, mouseLocation: point))
            XCTAssertTrue(CloseWindowMode.force.shouldClose(frame: frame, mouseLocation: point))
        }
        XCTAssertTrue(CloseWindowMode.original.shouldClose(frame: frame, mouseLocation: NSPoint(x: 400, y: 250)))
        XCTAssertFalse(CloseWindowMode.expanded.shouldClose(frame: frame, mouseLocation: NSPoint(x: 100, y: 100)))
        XCTAssertTrue(CloseWindowMode.expanded.shouldClose(frame: frame, mouseLocation: NSPoint(x: 99, y: 100)))
        XCTAssertTrue(CloseWindowMode.expanded.shouldClose(frame: frame, mouseLocation: NSPoint(x: 500, y: 250)))
    }
}

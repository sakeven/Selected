import AppKit
import CoreData
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class InlineResultTests: XCTestCase {
    func testSpotlightStartsCompact() {
        let host = NSHostingView(rootView: SpotlightView(target: ActionTarget(application: nil), bundleID: "", allActions: []))
        let size = host.fittingSize
        XCTAssertEqual(size.width, 520, accuracy: 1)
        XCTAssertLessThan(size.height, 140)
        XCTAssertGreaterThan(size.height, 60)
    }

    func testResultHeightFitsShortTextAndCapsLongText() {
        let short = NSHostingView(rootView: PopResultView(text: "翻译结果", editable: false)).fittingSize
        let medium = NSHostingView(rootView: PopResultView(text: Array(repeating: "这是一段多行结果。", count: 8).joined(separator: "\n"), editable: false)).fittingSize
        let long = NSHostingView(rootView: PopResultView(text: Array(repeating: "这是一段多行结果。", count: 100).joined(separator: "\n"), editable: false)).fittingSize
        XCTAssertLessThan(short.height, 100)
        XCTAssertGreaterThan(medium.height, short.height)
        XCTAssertGreaterThan(long.height, medium.height)
        XCTAssertLessThanOrEqual(long.height, 350)
        XCTAssertEqual(short.width, long.width, accuracy: 1)
    }

    func testResultStaysNearCapturedPositionAndInsideScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main?.visibleFrame)
        for point in [NSPoint(x: screen.midX, y: screen.midY),
                      NSPoint(x: screen.minX + 2, y: screen.minY + 2),
                      NSPoint(x: screen.maxX - 2, y: screen.maxY - 2)] {
            let controller = TextWindowController(text: String(repeating: "内容\n", count: 80), editable: false, at: point)
            let window = try XCTUnwrap(controller.window)
            defer { controller.close() }
            XCTAssertTrue(screen.insetBy(dx: -1, dy: -1).contains(window.frame))
            XCTAssertLessThan(window.frame.width, 500)
            XCTAssertGreaterThan(window.frame.height, 300)
            XCTAssertFalse(window.styleMask.contains(.resizable))
        }
    }

    func testShowUsesCompactWindowForTextAndWorkbenchForClipboardIncludingNextAction() async throws {
        var action = Action.new(kind: .runCommand)
        action.meta.after = .show
        action.runCommand?.pluginPath = NSTemporaryDirectory()
        let request = ActionRequest.plugin(Plugin.new(), action)
        let target = ActionTarget(application: nil)
        let frame = try XCTUnwrap(NSScreen.main?.visibleFrame)
        let position = NSPoint(x: frame.midX, y: frame.midY)
        let textInput = ActionInput(context: ActionInput.textContext("Inline result"))
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main]))
        let entity = try XCTUnwrap(model.entitiesByName["ClipHistoryData"])
        let clip = ClipHistoryData(entity: entity, insertInto: nil)
        clip.plainText = "Clipboard result"
        let clipboardInput = ActionInput(clip: clip)

        for (input, isCompact) in [(textInput, true), (clipboardInput, false), (clipboardInput.replacingText("Next result"), false)] {
            let existingWindows = Set(NSApp.windows.map(\.windowNumber))
            ActionCoordinator.perform(request, input: input, target: target, resultPosition: position)
            var result: NSWindow?
            for _ in 0..<100 {
                result = NSApp.windows.first { $0.isVisible && !existingWindows.contains($0.windowNumber) }
                if result != nil { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            let window = try XCTUnwrap(result)
            if isCompact {
                XCTAssertLessThan(window.frame.height, 100)
                XCTAssertLessThan(window.frame.width, 500)
                XCTAssertEqual(window.frame.midX, position.x, accuracy: 1)
            } else {
                XCTAssertGreaterThanOrEqual(window.frame.width, 560)
                XCTAssertGreaterThanOrEqual(window.frame.height, 410)
            }
            WindowManager.shared.closeAllWindows(.force)
            ActionResultWindow.shared.close()
        }
    }
}

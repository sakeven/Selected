import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class WindowBehaviorTests: XCTestCase {
    func testPinningAndSharingPreventAutomaticClosing() {
        let controller = BaseWindowController(rootView: AnyView(Text("Result")), windowType: .text,
                                              positionStrategy: .centerScreen, size: NSSize(width: 200, height: 100))
        defer { controller.close() }
        XCTAssertTrue(controller.canClose())
        controller.pinnedModel.pinned = true
        XCTAssertFalse(controller.canClose())
        controller.pinnedModel.pinned = false
        controller.showingSharingPicker.showing = true
        XCTAssertFalse(controller.canClose())
        controller.showingSharingPicker.showing = false
        XCTAssertTrue(controller.canClose())
    }

    func testWindowTypesKeepTheirAppearanceAndCloseCallback() throws {
        for type in [WindowType.popBar, .text, .translation, .tts] {
            let controller = BaseWindowController(rootView: AnyView(Text("Result")), windowType: type,
                                                  positionStrategy: .centerScreen, size: NSSize(width: 200, height: 100))
            let window = try XCTUnwrap(controller.window)
            XCTAssertEqual(window.isOpaque, type != .popBar && type != .text)
            XCTAssertEqual(window.backgroundColor, .clear)
            XCTAssertEqual(window.level, .screenSaver)
            XCTAssertEqual(controller.isPopbar(), type == .popBar)
            var closed = 0
            controller.onClose = { closed += 1 }
            controller.close()
            XCTAssertEqual(closed, 1)
        }
    }

    func testStoredWindowPositionRoundTripsWithoutChangingItsFormat() throws {
        let key = "SelectedTests.WindowPosition.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let manager = WindowPositionManager(key: key)
        let visible = try XCTUnwrap(NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main).visibleFrame
        let frame = NSRect(x: visible.midX - 160, y: visible.midY - 100, width: 320, height: 200)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        manager.storePosition(of: window)
        let data = try XCTUnwrap(UserDefaults.standard.data(forKey: key))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Double])
        XCTAssertEqual(Set(json.keys), ["sizeW", "sizeH", "centerRX", "centerRY"])
        XCTAssertEqual(json["sizeW"], 320)
        XCTAssertEqual(json["sizeH"], 200)
        window.setFrame(NSRect(x: visible.minX, y: visible.minY, width: 100, height: 100), display: false)
        XCTAssertTrue(manager.restorePosition(for: window))
        XCTAssertEqual(window.frame, frame)
    }

    func testMissingOrInvalidSavedPositionLeavesTheWindowUnchanged() {
        let key = "SelectedTests.WindowPosition.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let manager = WindowPositionManager(key: key)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 200, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let frame = window.frame
        XCTAssertFalse(manager.restorePosition(for: window))
        UserDefaults.standard.set(Data("invalid".utf8), forKey: key)
        XCTAssertFalse(manager.restorePosition(for: window))
        XCTAssertEqual(window.frame, frame)
    }

    func testClosingOnlyPopBarsPreservesOtherWindowsAndPinnedPanels() throws {
        let manager = WindowManager()
        let text = try createdController {
            manager.createTextWindow("Text result", editable: false, at: NSEvent.mouseLocation)
        }
        text.pinnedModel.pinned = true
        let pinnedBar = try createdController {
            manager.createPopBarWindow(ActionInput.textContext("Selected text"))
        }
        pinnedBar.pinnedModel.pinned = true
        let bar = try createdController {
            manager.createPopBarWindow(ActionInput.textContext("Another selection"))
        }
        defer {
            for controller in [text, pinnedBar, bar] { controller.close() }
        }

        XCTAssertFalse(manager.closeOnlyPopbarWindows(.force))
        XCTAssertFalse(try XCTUnwrap(bar.window).isVisible)
        XCTAssertTrue(try XCTUnwrap(pinnedBar.window).isVisible)
        XCTAssertTrue(try XCTUnwrap(text.window).isVisible)

        text.pinnedModel.pinned = false
        pinnedBar.pinnedModel.pinned = false
        XCTAssertFalse(manager.closeOnlyPopbarWindows(.force))
        XCTAssertFalse(try XCTUnwrap(pinnedBar.window).isVisible)
        XCTAssertTrue(try XCTUnwrap(text.window).isVisible)
        manager.closeAllWindows(.force)
        XCTAssertFalse(try XCTUnwrap(text.window).isVisible)
    }

    private func createdController(_ create: () -> Void) throws -> BaseWindowController {
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        create()
        let window = try XCTUnwrap(NSApp.windows.first { !existing.contains(ObjectIdentifier($0)) })
        return try XCTUnwrap(window.windowController as? BaseWindowController)
    }

    func testChatWindowsPreservePinningAndMouseCloseBoundaries() async throws {
        let savedPosition = UserDefaults.standard.object(forKey: "ChatWindowPosition")
        defer { UserDefaults.standard.set(savedPosition, forKey: "ChatWindowPosition") }
        UserDefaults.standard.removeObject(forKey: "ChatWindowPosition")
        let manager = ChatWindowManager()
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        manager.createChatWindow(chatService: WindowAIProvider(), withContext: ChatContext(text: "Fixture", webPageURL: "", bundleID: "selected.tests.unknown-app"))
        let window = try XCTUnwrap(NSApp.windows.first { !existing.contains(ObjectIdentifier($0)) })
        let controller = try XCTUnwrap(window.windowController as? ChatWindowController)
        defer { controller.close() }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(window.frame.size, NSSize(width: 780, height: 720))
        XCTAssertEqual(window.level, .screenSaver)
        XCTAssertFalse(window.hasShadow)
        XCTAssertFalse(window.isOpaque)
        controller.pinnedModel.pinned = true
        manager.closeAllWindows(.force)
        XCTAssertTrue(window.isVisible)
        controller.pinnedModel.pinned = false

        let point = NSEvent.mouseLocation
        window.setFrame(NSRect(x: point.x + 50, y: point.y - 50, width: 200, height: 100), display: false)
        manager.closeAllWindows(.expanded)
        XCTAssertTrue(window.isVisible)
        manager.closeAllWindows(.original)
        XCTAssertFalse(window.isVisible)
    }

    func testCollapsedChatRestoresItsExpandedFrameOnlyOnExpansion() {
        let original = NSRect(x: 120, y: 140, width: 780, height: 720)
        let window = FloatingPanel(contentRect: original, backing: .buffered, defer: false)
        defer { window.close() }
        let coordinator = ChatWindowStyleSync.Coordinator()
        coordinator.apply(to: window, isCollapsed: false, expandedFrame: nil)
        XCTAssertEqual(window.frame, original)
        XCTAssertEqual(window.contentMinSize, NSSize(width: 620, height: 520))
        XCTAssertTrue(window.styleMask.contains(.resizable))

        coordinator.apply(to: window, isCollapsed: true, expandedFrame: original)
        XCTAssertEqual(window.frame.size, NSSize(width: 52, height: 52))
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.isMovableByWindowBackground)
        coordinator.apply(to: window, isCollapsed: false, expandedFrame: original)
        XCTAssertEqual(window.frame, original)
        XCTAssertTrue(window.isMovableByWindowBackground)

        let moved = original.offsetBy(dx: 40, dy: 30)
        window.setFrame(moved, display: false)
        coordinator.apply(to: window, isCollapsed: false, expandedFrame: original)
        XCTAssertEqual(window.frame, moved)
    }
}

private struct WindowAIProvider: AIProvider {
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> { chatOnce(selectedText: ctx.text) }
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error> { chatOnce(selectedText: userMessage.text) }
}

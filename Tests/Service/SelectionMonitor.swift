import AppKit
import XCTest
@testable import Selected

@MainActor
final class SelectionMonitorTests: XCTestCase {
    private let selection = SelectedTextContext(Text: "word", BundleID: "selected.tests.popbar")
    private var bars: [PopBarWindowController] {
        NSApp.windows.compactMap { $0.windowController as? PopBarWindowController }
            .filter { $0.context.BundleID == selection.BundleID && $0.window?.isVisible == true }
    }

    func testClearingSelectionScrollingAndClickingOutsideCancelPendingDisplay() async throws {
        let windows = WindowManager(mouseLocation: { .zero })
        defer { windows.closeAllWindows(.force) }
        var context: SelectedTextContext? = selection
        let monitor = SelectionMonitor(windows: windows) { context }
        let selectAll = try key(Keycode.a, flags: .command)
        let wheel = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 10, wheel2: 0, wheel3: 0))
        let scroll = try XCTUnwrap(NSEvent(cgEvent: wheel))
        let interruptions = try [mouse(.leftMouseDown), mouse(.rightMouseDown), mouse(.leftMouseUp), scroll, key(Keycode.escape)]
        for event in interruptions {
            context = selection
            monitor.handle(selectAll, local: false)
            context = nil
            monitor.handle(event, local: false)
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertTrue(bars.isEmpty, "Selection survived \(event.type)")
        }
    }

    func testTripleClickUsesFinalTextAndKeepsTheSelectionPoint() async throws {
        let frame = try XCTUnwrap(NSScreen.main).visibleFrame
        let anchor = NSPoint(x: frame.midX, y: frame.midY)
        var pointer = anchor
        let windows = WindowManager(mouseLocation: { pointer })
        defer { windows.closeAllWindows(.force) }
        var context = selection
        let monitor = SelectionMonitor(windows: windows) { context }
        for click in 1...3 {
            if click == 3 { context.Text = "the entire line" }
            let time = 10 + Double(click) / 10
            monitor.handle(try mouse(.leftMouseDown, at: time, location: anchor), local: false)
            if click == 3 { pointer.x += 20 }
            monitor.handle(try mouse(.leftMouseUp, at: time + 0.01, location: anchor), local: false)
        }
        monitor.handle(try mouse(.mouseMoved), local: false)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(bars.map(\.context.Text), ["the entire line"])
        let bar = try XCTUnwrap(bars.first)
        XCTAssertEqual(bar.selectionPoint, anchor)
        let window = try XCTUnwrap(bar.window)
        let expected = WindowPositionStrategy.nearPoint(anchor).origin(windowFrame: window.frame, requestedSize: .zero, screenFrame: frame)
        XCTAssertEqual(window.frame.minX, expected.x, accuracy: 1)
        XCTAssertEqual(window.frame.minY, expected.y, accuracy: 1)

        pointer.x += window.frame.width + kExpandedLength
        monitor.handle(try mouse(.mouseMoved), local: false)
        XCTAssertTrue(bars.isEmpty)
        monitor.handle(try key(Keycode.a, flags: .command), local: false)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(bars.map(\.context.Text), ["the entire line"])
    }

    func testLeavingTheSelectionAreaBeforeDisplayDiscardsTheRequest() async throws {
        var pointer = NSPoint.zero
        let windows = WindowManager(mouseLocation: { pointer })
        defer { windows.closeAllWindows(.force) }
        windows.schedulePopBar(selection, at: pointer)
        pointer.x += kExpandedLength + 1
        windows.closeOnlyPopbarWindows(.expanded)
        pointer = .zero
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(bars.isEmpty)

        windows.schedulePopBar(selection, at: pointer)
        pointer.y += kExpandedLength + 1
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(bars.isEmpty)
    }

    func testEscapeOverTheToolbarAndRightClickBesideItDismissVisibleBars() throws {
        var pointer = NSEvent.mouseLocation
        let windows = WindowManager(mouseLocation: { pointer })
        defer { windows.closeAllWindows(.force) }
        let monitor = SelectionMonitor(windows: windows)
        for local in [false, true] {
            windows.createPopBarWindow(selection, at: pointer)
            let bar = try XCTUnwrap(bars.first)
            let frame = bar.frame()
            pointer = NSPoint(x: frame.midX, y: frame.midY)
            bar.showingSharingPicker.showing = true
            monitor.handle(try key(Keycode.escape), local: local)
            XCTAssertTrue(try XCTUnwrap(bar.window).isVisible)
            bar.showingSharingPicker.showing = false
            monitor.handle(try key(Keycode.escape), local: local)
            XCTAssertTrue(bars.isEmpty)
        }
        windows.createPopBarWindow(selection, at: pointer)
        let frame = try XCTUnwrap(bars.first).frame()
        pointer = NSPoint(x: frame.minX - 5, y: frame.midY)
        monitor.handle(try mouse(.rightMouseDown), local: false)
        XCTAssertTrue(bars.isEmpty)
    }

    func testPauseAndSpaceChangeDismissOpenAndPendingBars() async throws {
        let windows = WindowManager.shared
        let wasPaused = PauseModel.shared.pause
        defer {
            PauseModel.shared.pause = wasPaused
            windows.closeAllWindows(.force)
        }
        let delegate = AppDelegate()
        for dismiss: () -> Void in [{ PauseModel.shared.pause = true }, { delegate.spaceDidChange() }] {
            PauseModel.shared.pause = false
            windows.createPopBarWindow(selection)
            XCTAssertEqual(bars.count, 1)
            windows.schedulePopBar(SelectedTextContext(Text: "next", BundleID: selection.BundleID), at: NSEvent.mouseLocation)
            dismiss()
            XCTAssertTrue(bars.isEmpty)
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertTrue(bars.isEmpty)
        }
    }

    func testSelectionReaderCopyKeepsPendingBarAndUserCopyDismissesIt() async throws {
        let windows = WindowManager(mouseLocation: { .zero })
        defer { windows.closeAllWindows(.force) }
        let monitor = SelectionMonitor(windows: windows)
        windows.schedulePopBar(selection, at: .zero)
        let copy = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: Keycode.c, keyDown: true))
        copy.flags = .maskCommand
        copy.setIntegerValueField(.eventSourceUserData, value: selectionCopyEventTag)
        monitor.handle(try XCTUnwrap(NSEvent(cgEvent: copy)), local: false)
        windows.frontmostApplicationDidChange(to: selection.BundleID)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(bars.count, 1)
        monitor.handle(try key(Keycode.c, flags: .command), local: false)
        XCTAssertTrue(bars.isEmpty)

        windows.schedulePopBar(selection, at: .zero)
        windows.frontmostApplicationDidChange(to: "another.app")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(bars.isEmpty)
    }

    private func mouse(_ type: NSEvent.EventType, at time: TimeInterval = 10, location: NSPoint = .zero) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: time, windowNumber: 0,
                                         context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
    }

    private func key(_ code: UInt16, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 10, windowNumber: 0,
                                       context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
    }
}

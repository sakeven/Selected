import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class ActionProgressTests: XCTestCase {
    func testAIPasteShowsProgressWithoutTakingFocusOrChangingSelection() async throws {
        let field = NSTextField(string: "Original selection")
        let original = FloatingPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 80),
                                     backing: .buffered, defer: false, key: true)
        original.contentView = field
        original.makeKeyAndOrderFront(nil)
        original.makeFirstResponder(field)
        let editor = try XCTUnwrap(field.currentEditor())
        let selection = NSRange(location: 0, length: 8)
        editor.selectedRange = selection
        defer { original.close() }

        var action = Action.new(kind: .gpt)
        action.meta.after = .paste
        let progress = try start(action)
        defer { progress.close() }
        let window = try XCTUnwrap(progress.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(NSApp.keyWindow === original)
        XCTAssertEqual(editor.selectedRange, selection)
        XCTAssertTrue(progress.session.isRunning)

        progress.session.cancel()
        XCTAssertTrue(progress.session.isCancelling)
        XCTAssertFalse(progress.session.canCancel)
        try await waitFor { !progress.session.isRunning }
        XCTAssertFalse(progress.session.completed)
        XCTAssertFalse(progress.session.failed)
        XCTAssertTrue(progress.session.output.isEmpty)
    }

    func testBackgroundModesKeepProgressVisibleAndCancellationDoesNotApplyOutput() async throws {
        for after in [AfterAction.paste, .copy, .show, .none] {
            let progress = try start(command(after: after, script: "exec /bin/sleep 20"))
            defer { progress.close() }
            try await Task.sleep(for: .milliseconds(100))
            WindowManager.shared.closeAllWindows(.force)
            XCTAssertTrue(try XCTUnwrap(progress.window).isVisible)
            XCTAssertTrue(progress.session.isRunning)
            let pasteboardCount = NSPasteboard.general.changeCount

            progress.session.cancel()
            XCTAssertEqual(progress.session.message, String(localized: "Cancelling…"))
            try await waitFor { !progress.session.isRunning }
            XCTAssertFalse(progress.session.completed)
            XCTAssertFalse(progress.session.failed)
            XCTAssertTrue(progress.session.output.isEmpty)
            XCTAssertEqual(progress.session.message, String(localized: "Cancelled"))
            XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardCount)
            try await waitFor { progress.window?.isVisible == false }
            XCTAssertFalse(NSApp.windows.contains { $0.isVisible && $0.windowController is TextWindowController })
        }
    }

    func testCompletionIsVisibleBeforeProgressDismisses() async throws {
        let progress = try start(command(after: .none, script: "/bin/sleep 0.2; printf 'Finished result'"))
        defer { progress.close() }
        try await waitFor { !progress.session.isRunning }
        XCTAssertTrue(progress.session.completed)
        XCTAssertFalse(progress.session.failed)
        XCTAssertEqual(progress.session.output, "Finished result")
        XCTAssertEqual(progress.session.message, String(localized: "Completed"))
        XCTAssertTrue(try XCTUnwrap(progress.window).isVisible)
        try await waitFor { progress.window?.isVisible == false }
    }

    func testPasteFailureKeepsGeneratedTextAndOpensReadableError() async throws {
        let progress = try start(command(after: .paste, script: "/bin/sleep 0.2; printf 'Replacement result'"))
        defer {
            progress.close()
            WindowManager.shared.closeAllWindows(.force)
        }
        try await waitFor { !progress.session.isRunning }
        XCTAssertTrue(progress.session.failed)
        XCTAssertFalse(progress.session.completed)
        XCTAssertEqual(progress.session.output, "Replacement result")
        XCTAssertFalse(progress.session.message.isEmpty)
        try await waitFor { progress.window?.isVisible == false }
        XCTAssertTrue(NSApp.windows.contains { $0.isVisible && $0.windowController is TextWindowController })
    }

    func testPreviewUsesItsExistingProgressWithoutAnExtraWindow() throws {
        let existing = Set(NSApp.windows.map(\.windowNumber))
        ActionCoordinator.perform(.plugin(Plugin.new(), command(after: .xshow, script: "exec /bin/sleep 20")),
                                  input: ActionInput(context: ActionInput.textContext("Original input")),
                                  target: ActionTarget(application: nil))
        defer { ActionResultWindow.shared.close() }
        let windows = NSApp.windows.filter { $0.isVisible && !existing.contains($0.windowNumber) }
        XCTAssertEqual(windows.count, 1)
        XCTAssertFalse(windows.contains { $0.windowController is ActionProgressWindowController })
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(windows.first).frame.width, 560)
    }

    func testFinishingOneActionDoesNotHideAnotherRunningAction() async throws {
        let first = try start(command(after: .none, script: "/bin/sleep 0.2; printf 'Finished'"))
        let second = try start(command(after: .paste, script: "exec /bin/sleep 20"))
        defer { first.close(); second.close() }
        try await waitFor { first.window?.isVisible == false }
        XCTAssertTrue(second.session.isRunning)
        XCTAssertTrue(try XCTUnwrap(second.window).isVisible)
        second.session.cancel()
        try await waitFor { !second.session.isRunning }
        XCTAssertFalse(second.session.completed)
    }

    func testProgressFitsLongTitlesInLightAndDarkAppearance() async throws {
        var action = command(after: .paste, script: "exec /bin/sleep 20")
        action.meta.title = "生成命令 · Replace selected text"
        let progress = try start(action)
        defer { progress.close() }
        let window = try XCTUnwrap(progress.window)
        for scheme in [ColorScheme.light, .dark] {
            let host = NSHostingView(rootView: ActionProgressView(session: progress.session).environment(\.colorScheme, scheme))
            window.contentView = host
            window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
            window.setContentSize(host.fittingSize)
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(window.frame.width, 348, accuracy: 1)
            XCTAssertLessThan(window.frame.height, 100)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let image = NSImage(size: host.bounds.size)
            image.addRepresentation(bitmap)
            let attachment = XCTAttachment(image: image)
            attachment.name = "action-progress-\(scheme == .light ? "light" : "dark")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        progress.session.cancel()
        try await waitFor { !progress.session.isRunning }
    }

    private func start(_ action: Action) throws -> ActionProgressWindowController {
        let existing = Set(NSApp.windows.map(\.windowNumber))
        ActionCoordinator.perform(.plugin(Plugin.new(), action),
                                  input: ActionInput(context: ActionInput.textContext("Original input")),
                                  target: ActionTarget(application: nil))
        let window = try XCTUnwrap(NSApp.windows.first { $0.isVisible && !existing.contains($0.windowNumber) })
        return try XCTUnwrap(window.windowController as? ActionProgressWindowController)
    }

    private func command(after: AfterAction, script: String) -> Action {
        var action = Action.new(kind: .runCommand)
        action.meta.after = after
        action.runCommand?.command = ["/bin/sh", "-c", script]
        action.runCommand?.pluginPath = NSTemporaryDirectory()
        return action
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Action did not reach the expected state")
    }
}

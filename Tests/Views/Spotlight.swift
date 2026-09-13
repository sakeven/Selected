import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class SpotlightViewTests: XCTestCase {
    func testKeyboardSearchThenEnterActionInputAndRun() async throws {
        var received: [String] = []
        let action = PerformAction(actionMeta: GenericAction(title: "Spotlight Fixture", icon: "symbol:text.quote", identifier: "spotlight.fixture"),
                                   complete: { received.append($0.Text) })
        action.actionMeta.requirements = [.text]
        let host = NSHostingView(rootView: SpotlightView(target: ActionTarget(application: nil), bundleID: "selected.tests.unknown-app", allActions: [action]))
        let window = FloatingPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .closable], backing: .buffered, defer: false, key: true)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        let field = try XCTUnwrap(textField(in: host))
        window.makeFirstResponder(field)
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.insertText("Spotlight Fixture", replacementRange: NSRange(location: 0, length: 0))
        try await Task.sleep(for: .milliseconds(250))
        try attach(host, name: "spotlight-action-search")
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "")
        XCTAssertTrue(received.isEmpty)
        let inputEditor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        inputEditor.insertText("Actual input 原始内容", replacementRange: NSRange(location: 0, length: 0))
        try await Task.sleep(for: .milliseconds(100))
        try attach(host, name: "spotlight-action-input")
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(received, ["Actual input 原始内容"])
    }

    func testTabKeepsInputAndEscapeReturnsToSearch() async throws {
        let host = NSHostingView(rootView: SpotlightView(target: ActionTarget(application: nil), bundleID: "", allActions: []))
        let window = FloatingPanel(contentRect: .zero, backing: .buffered, defer: false, key: true)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(150))
        let field = try XCTUnwrap(textField(in: host))
        window.makeFirstResponder(field)
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        let original = "Original input\n第二行  "
        editor.insertText(original, replacementRange: NSRange(location: 0, length: 0))
        sendKey("\t", code: 48, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, original)
        XCTAssertEqual(field.placeholderString, "Type or paste text…")
        sendKey("\u{1b}", code: 53, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, original)
        XCTAssertEqual(field.placeholderString, "Search apps, files, and more…")
    }

    func testGroupedResultsInLightAndDarkAppearance() async throws {
        let action = PerformAction(actionMeta: GenericAction(title: "Translate text", icon: "symbol:globe", identifier: "translate"), complete: { _ in })
        let app = SpotlightItem(id: "app:textedit", title: "TextEdit", subtitle: "/System/Applications",
                                content: .application(URL(fileURLWithPath: "/System/Applications/TextEdit.app")))
        let file = SpotlightItem.file(URL(fileURLWithPath: "/Users/example/Documents/Text notes.txt"))
        let textEntry = SpotlightItem(id: "text-actions", title: "Actions for Input Text", subtitle: "Text", content: .textActions)
        let clip = try makeClipboardFixture(text: "Text copied from yesterday’s meeting notes",
                                            representations: [(.string, Data("Text copied from yesterday’s meeting notes".utf8))])
        clip.application = "com.apple.TextEdit"
        let files = (1...12).map { SpotlightItem.file(URL(fileURLWithPath: "/Users/example/Documents/Text notes \($0).txt")) }
        for scheme in [ColorScheme.light, .dark] {
            for (fixture, items) in [("all", [app, .action(action), file, textEntry]),
                                     ("actions", [.action(action), textEntry]),
                                     ("clipboard", [app, .clipboard(clip), textEntry]),
                                     ("files-collapsed", SpotlightSearch.previewResults(files) + [textEntry])] {
                let host = NSHostingView(rootView: SpotlightResultsView(results: items, selectedID: items.first?.id, isSearchMode: true,
                                                                        select: { _ in }, preview: { _ in }, reveal: { _ in })
                    .frame(width: 520)
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    .environment(\.colorScheme, scheme))
                let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.contentView = host
                window.setContentSize(host.fittingSize)
                window.orderFront(nil)
                defer { window.close() }
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertLessThanOrEqual(host.fittingSize.height, 421)
                let name = "application-spotlight-grouped-\(fixture)-\(scheme == .light ? "light" : "dark")"
                try attach(host, name: name, snapshotName: name)
            }
        }
    }

    func testKeyboardOpensMoreResultsAndEscapeReturnsToCollapsedOverview() async throws {
        var received: [String] = []
        let actions = (1...6).map { index in
            let action = PerformAction(actionMeta: GenericAction(title: "Spotlight Overflow \(index)", icon: "symbol:star", identifier: "overflow.\(index)"),
                                       complete: { received.append("\(index):" + $0.Text) })
            action.actionMeta.requirements = [.text]
            return action
        }
        let host = NSHostingView(rootView: SpotlightView(target: ActionTarget(application: nil), bundleID: "selected.tests.unknown-app", allActions: actions))
        let window = FloatingPanel(contentRect: .zero, backing: .buffered, defer: false, key: true)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(150))
        let field = try XCTUnwrap(textField(in: host))
        window.makeFirstResponder(field)
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.insertText("Spotlight Overflow", replacementRange: NSRange(location: 0, length: 0))
        try await Task.sleep(for: .milliseconds(200))
        for _ in 0..<3 {
            sendKey("\u{f701}", code: 125, to: window)
            try await Task.sleep(for: .milliseconds(30))
        }
        try attach(host, name: "spotlight-more-selected")
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "Spotlight Overflow")
        try attach(host, name: "spotlight-category-results")
        sendKey("\u{1b}", code: 53, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "Spotlight Overflow")
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        for _ in 0..<4 {
            sendKey("\u{f701}", code: 125, to: window)
            try await Task.sleep(for: .milliseconds(30))
        }
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(field.stringValue, "")
        let inputEditor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        inputEditor.insertText("Actual input", replacementRange: NSRange(location: 0, length: 0))
        sendKey("\r", code: 36, to: window)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(received, ["5:Actual input"])
    }

    func testMarkedTextKeepsArrowAndReturnCommandsWithTheInputMethod() {
        var moves: [Int] = []
        var submissions = 0
        let searchField = SpotlightSearchField(text: .constant(""), isFocused: .constant(true), placeholder: "Search",
                                               moveSelection: { moves.append($0) }, submit: { submissions += 1 },
                                               tab: { true }, cancel: {})
        let coordinator = searchField.makeCoordinator()
        let field = NSTextField()
        let editor = NSTextView()
        editor.setMarkedText("报告", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        for selector in [#selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)),
                         #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)),
                         #selector(NSResponder.cancelOperation(_:))] {
            XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: selector))
        }
        XCTAssertTrue(moves.isEmpty)
        XCTAssertEqual(submissions, 0)
        editor.unmarkText()
        XCTAssertTrue(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertTrue(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(moves, [1])
        XCTAssertEqual(submissions, 1)
    }

    private func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { self.textField(in: $0) }.first
    }

    private func sendKey(_ characters: String, code: UInt16, to window: NSWindow) {
        let flags: NSEvent.ModifierFlags = (123...126).contains(code) ? [.function, .numericPad] : []
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                    windowNumber: window.windowNumber, context: nil, characters: characters,
                                    charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
        window.sendEvent(event)
    }

    private func attach(_ host: NSView, name: String, snapshotName: String? = nil) throws {
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(bitmap)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let snapshotName { try assertSnapshot(bitmap, named: snapshotName) }
    }
}

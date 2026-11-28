import AppKit
import CoreData
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class ClipboardLayoutTests: XCTestCase {
    func testClipboardLayoutInLightAndDarkAppearance() async throws {
        let model = PersistenceController.shared.container.managedObjectModel
        let article = """
        先记下来，让思路清楚起来。

        一段口述、一张照片、一篇网页，都可以成为一条整理好的笔记。原始材料和 AI 结果放在一起，需要时随时回看。

        ↗ 文字、照片、PDF 与网页统一收集
        ↗ 录音、转写与实时整理
        """
        let scenarios: [(String, [(NSPasteboard.PasteboardType, String)])] = [
            ("empty", []), ("text", [(.string, "First line\n第二行")]),
            ("json", [(.string, "{\"count\":3,\"active\":true}")]), ("link", [(.string, "https://example.test/article")]),
            ("mixed", [(.string, "周会行动清单\n\n本周先把采访提纲定下来，周四和编辑一起过稿。\n\n• 整理三位受访者的时间\n• 把样刊发给编辑部\n• 周五前确认封面照片"),
                       (.URL, "https://developer.apple.com/design/"), (.color, ""), (.fileURL, "file:///Users/Shared/采访提纲.pdf"),
                       (.rtf, "十一月出版计划"), (.html, "Release checklist")]),
            ("web", [(.color, ""), (.rtf, "@available(iOS 17.0, *)"), (.html, article),
                     (.html, "随手记下，用 AI 理清，再继续写。"), (.string, "还有个一直在磨的地方是误触。"),
                     (.string, "251 项 macOS 测试全部通过"), (.fileURL, "file:///Users/Shared/采访提纲.pdf"),
                     (.URL, "https://developer.apple.com/design/"), (.string, "周四和编辑一起过稿"),
                     (.rtf, "十一月出版计划"), (.string, "周五前确认封面照片")])
        ]
        for (name, entries) in scenarios {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
            let context = NSManagedObjectContext(.mainQueue)
            context.persistentStoreCoordinator = coordinator
            var selectedArticle: ClipHistoryData?
            for (index, entry) in entries.enumerated() {
                let (type, text) = entry
                let clip = ClipHistoryData(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryData"]), insertInto: context)
                if name == "mixed" || name == "web" {
                    clip.isPinned = index == 0
                    switch type {
                    case .URL, .html: clip.application = "com.apple.Safari"
                    case .fileURL: clip.application = "com.apple.finder"
                    case .color: clip.application = "com.apple.Preview"
                    default: clip.application = "com.apple.Notes"
                    }
                } else {
                    clip.application = "selected.tests.missing-application"
                }
                clip.plainText = text
                if type == .URL || type == .fileURL { clip.url = text }
                clip.firstCopiedAt = Date(timeIntervalSince1970: 1_700_000_000 - Double(index))
                clip.lastCopiedAt = clip.firstCopiedAt
                clip.numberOfCopies = 1
                let representations: [(NSPasteboard.PasteboardType, String)]
                switch type {
                case .rtf: representations = [(.rtf, "{\\rtf1 \(text)}"), (.string, text)]
                case .html where text == article:
                    selectedArticle = clip
                    let paragraphs = article.components(separatedBy: "\n\n")
                    let html = """
                    <meta charset="utf-8"><style>span { background: #e8eddf; color: #586753 } h1 { font-size: 64px } p { font-size: 30px }</style>
                    <h1><span>\(paragraphs[0])</span></h1>
                    <p><span>\(paragraphs[1])</span></p><p><span>\(paragraphs[2].replacingOccurrences(of: "\n", with: "<br>"))</span></p>
                    """
                    representations = [(.html, html), (.string, text)]
                case .html: representations = [(.html, "<p>\(text)</p>"), (.string, text)]
                default: representations = [(type, text)]
                }
                for (format, content) in representations {
                    let item = ClipHistoryItem(context: context)
                    item.type = format.rawValue
                    if format == .color {
                        let swatch = NSColor(srgbRed: 115 / 255, green: 155 / 255, blue: 134 / 255, alpha: 1)
                        item.data = try XCTUnwrap(colorToData(color: swatch))
                    } else {
                        item.data = Data(content.utf8)
                    }
                    clip.addToItems(item)
                }
            }
            try context.save()

            for scheme in [ColorScheme.light, .dark] {
                let viewModel = ClipViewModel()
                viewModel.selectedItem = selectedArticle
                let host = NSHostingView(rootView: ClipView(viewModel: viewModel)
                    .environment(\.managedObjectContext, context)
                    .environment(\.colorScheme, scheme)
                    .environment(\.locale, .current))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.animationBehavior = .none
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.contentView = host
                // Keep pointer hover styling out of the snapshots.
                window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
                window.orderFront(nil)
                for shortcuts in name == "mixed" ? [false, true] : [false] {
                    viewModel.showsQuickPasteKeys = shortcuts
                    try await Task.sleep(for: .milliseconds(200))
                    host.layoutSubtreeIfNeeded()
                    XCTAssertEqual(host.fittingSize, NSSize(width: 960, height: 600))
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let image = NSImage(size: host.bounds.size)
                    image.addRepresentation(bitmap)
                    let attachment = XCTAttachment(image: image)
                    let language = Locale.current.language.languageCode?.identifier == "zh" ? "-zh" : ""
                    let snapshotName = "clipboard-\(shortcuts ? "quick-paste" : name)\(language)-\(scheme == .light ? "light" : "dark")"
                    attachment.name = snapshotName
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    XCTAssertNoThrow(try assertSnapshot(bitmap, named: snapshotName))
                }
                window.close()
            }
        }
    }

    func testSearchAndArrowKeysUpdateTheVisibleSelection() async throws {
        let model = PersistenceController.shared.container.managedObjectModel
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        var clips: [ClipHistoryData] = []
        for (index, text) in ["Pinned note", "Older note", "Newer note"].enumerated() {
            let clip = ClipHistoryData(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryData"]), insertInto: context)
            clip.application = "selected.tests.missing-application"
            clip.plainText = text
            clip.isPinned = index == 0
            clip.firstCopiedAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            clip.lastCopiedAt = clip.firstCopiedAt
            clip.numberOfCopies = 1
            clips.append(clip)
        }
        try context.save()
        let viewModel = ClipViewModel()
        let host = NSHostingView(rootView: ClipView(viewModel: viewModel).environment(\.managedObjectContext, context))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(viewModel.selectedItem, clips[0])
        let field = try XCTUnwrap(searchField(in: host))
        let searchPosition = host.convert(field.bounds, from: field).midY
        let delegate = try XCTUnwrap(field.delegate as? CustomSearchField.Coordinator)
        for expected in [clips[2], clips[1], clips[0]] {
            XCTAssertTrue(delegate.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:))))
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(viewModel.selectedItem, expected)
        }
        for (query, expected) in [("OLDER", clips[1]), ("no matching note", nil), ("", clips[0])] as [(String, ClipHistoryData?)] {
            field.stringValue = query
            delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(viewModel.selectedItem, expected)
            XCTAssertEqual(host.convert(field.bounds, from: field).midY, searchPosition, accuracy: 1)
        }
    }

    func testSearchReceivesFocusWhenClipboardOpens() async throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.shared.container.managedObjectModel)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = coordinator
        let host = NSHostingView(rootView: ClipView(viewModel: ClipViewModel()).environment(\.managedObjectContext, context))
        let window = FloatingPanel(contentRect: .zero, backing: .buffered, defer: false, key: true)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))
        let field = try XCTUnwrap(searchField(in: host))
        XCTAssertNotNil(field.currentEditor())
    }

    func testCommandDigitsPasteTheNumberedResultAcrossGroupsAndAfterSearch() async throws {
        let model = PersistenceController.shared.container.managedObjectModel
        let store = NSPersistentStoreCoordinator(managedObjectModel: model)
        try store.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(.mainQueue)
        context.persistentStoreCoordinator = store
        for index in 0...10 {
            let clip = ClipHistoryData(context: context)
            clip.application = "selected.tests.missing-application"
            clip.plainText = "Entry \(index)"
            clip.isPinned = index == 0
            clip.lastCopiedAt = Date(timeIntervalSince1970: Double(index))
        }
        try context.save()

        let viewModel = ClipViewModel()
        var restored: [String] = []
        var didPaste: [Bool] = []
        let view = ClipView(viewModel: viewModel) { clip, paste in
            restored.append(clip.plainText ?? "")
            didPaste.append(paste)
        }
        let originalPosition = UserDefaults.standard.object(forKey: "ClipboardWindowPosition")
        let controller = ClipWindowController(rootView: AnyView(view.environment(\.managedObjectContext, context)), viewModel: viewModel)
        controller.showWindow(nil)
        defer {
            controller.close()
            UserDefaults.standard.set(originalPosition, forKey: "ClipboardWindowPosition")
        }
        let window = try XCTUnwrap(controller.window)
        try await Task.sleep(for: .milliseconds(200))
        let field = try XCTUnwrap(searchField(in: try XCTUnwrap(window.contentView)))
        let delegate = try XCTUnwrap(field.delegate as? CustomSearchField.Coordinator)
        func key(_ characters: String, flags: NSEvent.ModifierFlags, type: NSEvent.EventType = .keyDown, repeatKey: Bool = false) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                                          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                          context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                          isARepeat: repeatKey, keyCode: KeycodeMapping[characters] ?? 0))
        }

        NSApp.postEvent(try key("2", flags: .command), atStart: false)
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertEqual(restored, ["Entry 10"])
        NSApp.postEvent(try key("", flags: .command, type: .flagsChanged), atStart: false)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(viewModel.showsQuickPasteKeys)
        XCTAssertTrue(controller.handleKeyEvent(try key("1", flags: .command)))
        XCTAssertTrue(controller.handleKeyEvent(try key("9", flags: [.command, .numericPad])))
        XCTAssertFalse(controller.handleKeyEvent(try key("0", flags: .command)))
        XCTAssertFalse(controller.handleKeyEvent(try key("1", flags: [])))
        XCTAssertFalse(controller.handleKeyEvent(try key("2", flags: [.command, .shift])))
        XCTAssertTrue(controller.handleKeyEvent(try key("2", flags: .command, repeatKey: true)))
        XCTAssertEqual(restored, ["Entry 10", "Entry 0", "Entry 3"])
        NSApp.postEvent(try key("", flags: [], type: .flagsChanged), atStart: false)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(viewModel.showsQuickPasteKeys)

        field.stringValue = "Entry 1"
        delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertTrue(controller.handleKeyEvent(try key("2", flags: .command)))
        XCTAssertFalse(controller.handleKeyEvent(try key("3", flags: .command)))
        XCTAssertTrue(controller.handleKeyEvent(try key("\r", flags: .command)))
        XCTAssertTrue(controller.handleKeyEvent(try key("\r", flags: [])))
        XCTAssertEqual(restored.suffix(3), ["Entry 1", "Entry 10", "Entry 10"])
        XCTAssertEqual(didPaste.suffix(3), [true, false, true])
        XCTAssertTrue(controller.handleKeyEvent(try key("p", flags: .command)))
        XCTAssertEqual(viewModel.selectedItem?.isPinned, true)
        XCTAssertEqual(ClipShortcut(event: try key("\r", flags: [.option, .shift])), .pastePlainText)
        XCTAssertEqual(ClipShortcut(event: try key("\u{7f}", flags: [.command, .shift])), .delete)

        let incoming = ClipHistoryData(context: context)
        incoming.application = "selected.tests.missing-application"
        incoming.plainText = "Entry 11"
        incoming.lastCopiedAt = Date(timeIntervalSince1970: 11)
        try context.save()
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertTrue(controller.handleKeyEvent(try key("2", flags: .command)))
        XCTAssertEqual(restored.last, "Entry 11")
        XCTAssertTrue(controller.handleKeyEvent(try key("\u{7f}", flags: [.command, .shift])))
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertEqual(viewModel.selectedItem, incoming)
        XCTAssertTrue(controller.handleKeyEvent(try key("1", flags: .command)))
        XCTAssertEqual(restored.last, "Entry 11")

        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.setMarkedText("拼", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertFalse(controller.handleKeyEvent(try key("1", flags: .command)))
        XCTAssertFalse(controller.handleKeyEvent(try key("\r", flags: [])))
        editor.unmarkText()
        XCTAssertEqual(restored.count, 8)
    }

    func testSearchArrowsDoNotInterruptChineseComposition() {
        var moves: [CustomSearchField.ArrowDirection] = []
        let search = CustomSearchField(text: .constant(""), isFocused: .constant(true), onArrowKey: { moves.append($0) },
                                       textColor: .labelColor, placeholderColor: .secondaryLabelColor)
        let coordinator = search.makeCoordinator()
        let field = NSTextField()
        let editor = NSTextView()
        editor.setMarkedText("内容", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        for selector in [#selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:))] {
            XCTAssertFalse(coordinator.control(field, textView: editor, doCommandBy: selector))
        }
        XCTAssertTrue(moves.isEmpty)
        editor.unmarkText()
        XCTAssertTrue(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertEqual(moves.count, 1)
    }

    private func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.delegate is CustomSearchField.Coordinator { return field }
        return view.subviews.lazy.compactMap { self.searchField(in: $0) }.first
    }
}

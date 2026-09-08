import AppKit
import CoreData
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class ClipboardLayoutTests: XCTestCase {
    func testClipboardLayoutInLightAndDarkAppearance() async throws {
        let model = PersistenceController.shared.container.managedObjectModel
        for (name, text) in [("empty", nil), ("text", "First line\n第二行"), ("json", "{\"count\":3,\"active\":true}"), ("link", "https://example.test/article")] as [(String, String?)] {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
            let context = NSManagedObjectContext(.mainQueue)
            context.persistentStoreCoordinator = coordinator
            if let text {
                let clip = ClipHistoryData(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryData"]), insertInto: context)
                clip.application = "selected.tests.missing-application"
                clip.plainText = text
                clip.firstCopiedAt = Date(timeIntervalSince1970: 1_700_000_000)
                clip.lastCopiedAt = clip.firstCopiedAt
                clip.numberOfCopies = 1
                let item = ClipHistoryItem(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryItem"]), insertInto: context)
                item.type = NSPasteboard.PasteboardType.string.rawValue
                item.data = Data(text.utf8)
                clip.addToItems(item)
            }
            try context.save()

            for scheme in [ColorScheme.light, .dark] {
                let host = NSHostingView(rootView: ClipView()
                    .environment(\.managedObjectContext, context)
                    .environment(\.colorScheme, scheme)
                    .environment(\.locale, Locale(identifier: "en_US")))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.contentView = host
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(200))
                host.layoutSubtreeIfNeeded()
                XCTAssertEqual(host.fittingSize, NSSize(width: 960, height: 600))
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let image = NSImage(size: host.bounds.size)
                image.addRepresentation(bitmap)
                let attachment = XCTAttachment(image: image)
                let snapshotName = "clipboard-\(name)-\(scheme == .light ? "light" : "dark")"
                attachment.name = snapshotName
                attachment.lifetime = .keepAlways
                add(attachment)
                try assertSnapshot(bitmap, named: snapshotName)
                window.close()
            }
        }
        ClipViewModel.shared.selectedItem = nil
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
        let host = NSHostingView(rootView: ClipView().environment(\.managedObjectContext, context))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.close()
            ClipViewModel.shared.selectedItem = nil
        }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(ClipViewModel.shared.selectedItem, clips[0])
        let field = try XCTUnwrap(searchField(in: host))
        let delegate = try XCTUnwrap(field.delegate as? CustomSearchField.Coordinator)
        for expected in [clips[2], clips[1], clips[0]] {
            XCTAssertTrue(delegate.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:))))
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(ClipViewModel.shared.selectedItem, expected)
        }
        for (query, expected) in [("OLDER", clips[1]), ("no matching note", nil), ("", clips[0])] as [(String, ClipHistoryData?)] {
            field.stringValue = query
            delegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(ClipViewModel.shared.selectedItem, expected)
        }
    }

    private func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.delegate is CustomSearchField.Coordinator { return field }
        return view.subviews.lazy.compactMap { self.searchField(in: $0) }.first
    }
}

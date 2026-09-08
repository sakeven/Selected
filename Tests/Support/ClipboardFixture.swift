import AppKit
import CoreData
import XCTest
@testable import Selected

@MainActor
func makeClipboardFixture(text: String? = nil, url: String? = nil,
                          representations: [(NSPasteboard.PasteboardType, Data)] = []) throws -> ClipHistoryData {
    let model = PersistenceController.shared.container.managedObjectModel
    let clip = ClipHistoryData(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryData"]), insertInto: nil)
    clip.plainText = text
    clip.url = url
    for (type, bytes) in representations {
        let item = ClipHistoryItem(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryItem"]), insertInto: nil)
        item.type = type.rawValue
        item.data = bytes
        clip.addToItems(item)
    }
    return clip
}

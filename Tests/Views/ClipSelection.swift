import XCTest
@testable import Selected

@MainActor
final class ClipSelectionTests: XCTestCase {
    func testDownStartsAtFirstItemAndWrapsAfterTheLast() throws {
        let clips = try ["A", "B", "C"].map { try makeClipboardFixture(text: $0) }
        XCTAssertEqual(ClipSelection(clips: clips, selected: nil).moving(.down), clips[0])
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[0]).moving(.down), clips[1])
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[2]).moving(.down), clips[0])
    }

    func testUpStopsAtFirstItemAndDoesNotInventASelection() throws {
        let clips = try ["A", "B", "C"].map { try makeClipboardFixture(text: $0) }
        XCTAssertNil(ClipSelection(clips: clips, selected: nil).moving(.up))
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[0]).moving(.up), clips[0])
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[2]).moving(.up), clips[1])
    }

    func testEmptyAndFilteredListsKeepCurrentKeyboardBehavior() throws {
        let selected = try makeClipboardFixture(text: "Selected")
        let other = try makeClipboardFixture(text: "Other")
        for direction in [CustomSearchField.ArrowDirection.up, .down] {
            XCTAssertEqual(ClipSelection(clips: [], selected: selected).moving(direction), selected)
        }
        XCTAssertEqual(ClipSelection(clips: [other], selected: selected).moving(.down), other)
        XCTAssertEqual(ClipSelection(clips: [other], selected: selected).moving(.up), selected)
    }

    func testDeletingSelectedItemChoosesItsNextOrPreviousNeighbor() throws {
        let clips = try ["A", "B", "C"].map { try makeClipboardFixture(text: $0) }
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[0]).indexAfterDeleting(clips[0]), 0)
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[1]).indexAfterDeleting(clips[1]), 1)
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[2]).indexAfterDeleting(clips[2]), 1)
        XCTAssertNil(ClipSelection(clips: [clips[0]], selected: clips[0]).indexAfterDeleting(clips[0]))
    }

    func testDeletingOtherItemsKeepsSelectionOnTheSameItem() throws {
        let clips = try ["A", "B", "C"].map { try makeClipboardFixture(text: $0) }
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[1]).indexAfterDeleting(clips[0]), 0)
        XCTAssertEqual(ClipSelection(clips: clips, selected: clips[1]).indexAfterDeleting(clips[2]), 1)
        XCTAssertEqual(ClipSelection(clips: clips, selected: nil).indexAfterDeleting(clips[1]), 0)
    }
}

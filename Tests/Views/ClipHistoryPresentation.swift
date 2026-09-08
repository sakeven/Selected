import AppKit
import XCTest
@testable import Selected

@MainActor
final class ClipHistoryPresentationTests: XCTestCase {
    func testPrimaryRepresentationDeterminesThePreviewKind() throws {
        let cases: [(NSPasteboard.PasteboardType, ClipDisplayKind)] = [
            (.color, .color), (.fileURL, .file), (.png, .image), (.tiff, .image),
            (.URL, .link), (.string, .text), (.rtf, .richText), (.html, .html),
            (.pdf, .unknown)
        ]
        for (type, kind) in cases {
            let clip = try makeClipboardFixture(text: "Text", representations: [(type, Data("payload".utf8))])
            XCTAssertEqual(clip.displayKind, kind, type.rawValue)
            XCTAssertEqual(clip.primaryPasteboardType, type)
        }
    }

    func testHTMLAndRTFTakePrecedenceOverPlainTextInEitherOrder() throws {
        let text = Data("Plain text".utf8)
        let rtf = Data("RTF".utf8)
        let html = Data("<b>HTML</b>".utf8)
        let cases: [[(NSPasteboard.PasteboardType, Data)]] = [
            [(.string, text), (.rtf, rtf), (.html, html)],
            [(.html, html), (.string, text), (.rtf, rtf)],
            [(.rtf, rtf), (.html, html), (.string, text)]
        ]
        for representations in cases {
            let clip = try makeClipboardFixture(text: "Plain text", representations: representations)
            XCTAssertEqual(clip.displayKind, .html)
            XCTAssertEqual(clip.htmlData, html)
            XCTAssertEqual(clip.rtfData, rtf)
        }
        let richText = try makeClipboardFixture(text: "https://example.test", representations: [(.string, text), (.rtf, rtf)])
        XCTAssertEqual(richText.displayKind, .richText)
    }

    func testFilesAndImagesRemainPrimaryEvenWithTextAndHTML() throws {
        for type in [NSPasteboard.PasteboardType.fileURL, .png] {
            let clip = try makeClipboardFixture(text: "OCR", representations: [
                (type, Data("payload".utf8)), (.string, Data("OCR".utf8)), (.html, Data("<p>OCR</p>".utf8))
            ])
            XCTAssertEqual(clip.displayKind, type == .fileURL ? .file : .image)
        }
    }

    func testMissingRepresentationsAndEmptyTextKeepTheirFallbacks() throws {
        let unknown = try makeClipboardFixture()
        XCTAssertEqual(unknown.displayKind, .unknown)
        XCTAssertEqual(unknown.rowTitle, "Clipboard Item")
        let empty = try makeClipboardFixture(text: " \n\t")
        XCTAssertEqual(empty.displayKind, .text)
        XCTAssertNil(empty.cleanedPreviewText)
        XCTAssertEqual(empty.rowTitle, String(localized: "Plain Text"))
        XCTAssertEqual(try makeClipboardFixture(text: "https://example.test").displayKind, .link)
    }

    func testTitlesRemoveLineBreaksWithoutChangingStoredText() throws {
        let text = "  First\r\nsecond\nthird\rfourth  "
        let clip = try makeClipboardFixture(text: text)
        XCTAssertEqual(clip.cleanedPreviewText, "First\r\nsecond\nthird\rfourth")
        XCTAssertEqual(clip.rowTitle, "Firstsecondthirdfourth")
        XCTAssertEqual(clip.detailTitle, clip.rowTitle)
        XCTAssertEqual(clip.plainText, text)
    }

    func testFileNamesAndLocationsDecodeEscapedPaths() throws {
        let value = "file:///tmp/Project%20Notes/%E4%BC%9A%E8%AE%AE%20Notes.txt"
        let clip = try makeClipboardFixture(representations: [(.fileURL, Data(value.utf8))])
        XCTAssertEqual(clip.rowTitle, "会议 Notes.txt")
        XCTAssertEqual(clip.detailTitle, "会议 Notes.txt")
        XCTAssertEqual(clip.displayURLString, "/tmp/Project Notes/会议 Notes.txt")
        XCTAssertEqual(clip.locationInfo?.title, "Path")
        XCTAssertEqual(clip.locationInfo?.value, clip.displayURLString)
        XCTAssertTrue(clip.matchesSearch("会议 notes"))
    }

    func testSearchMatchesTextURLsAndPreservesWhitespaceRules() throws {
        let clip = try makeClipboardFixture(text: "Hello 世界", url: "https://example.test/Article")
        for query in ["", "HELLO", "世界", "EXAMPLE", "article"] {
            XCTAssertTrue(clip.matchesSearch(query), query)
        }
        XCTAssertFalse(clip.matchesSearch(" Hello"))
        XCTAssertFalse(clip.matchesSearch("missing"))
        XCTAssertTrue(try makeClipboardFixture().matchesSearch(""))
        XCTAssertFalse(try makeClipboardFixture().matchesSearch("anything"))
    }

    func testLinkDisplayPrefersSourceURLAndKeepsOriginalText() throws {
        let clip = try makeClipboardFixture(text: "https://example.test/text", url: "https://example.test/source")
        XCTAssertEqual(clip.rowTitle, "https://example.test/source")
        XCTAssertEqual(clip.locationInfo?.title, "URL")
        XCTAssertEqual(clip.plainText, "https://example.test/text")
        for value in ["https://example.test/path", "http://localhost"] { XCTAssertTrue(isValidHttpUrl(value)) }
        for value in ["file:///tmp/a", "app://-/index.html", "https:", "plain text"] { XCTAssertFalse(isValidHttpUrl(value)) }
    }

    func testMetadataAndJSONActionAvailabilityKeepTheirExistingRules() throws {
        let clip = try makeClipboardFixture(text: "{\"count\":1}")
        XCTAssertTrue(clip.isJSON)
        clip.plainText = "[1,2]"
        XCTAssertTrue(clip.isJSON)
        clip.plainText = "not JSON"
        XCTAssertFalse(clip.isJSON)
        XCTAssertEqual(clip.firstCopiedText, "-")
        XCTAssertNil(clip.lastCopiedText)
        clip.numberOfCopies = 1
        clip.lastCopiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(clip.copiesText, "1")
        XCTAssertNil(clip.lastCopiedText)
        clip.numberOfCopies = 2
        XCTAssertEqual(clip.lastCopiedText, format(try XCTUnwrap(clip.lastCopiedAt)))
        XCTAssertEqual(clip.copiesText, String(format: String(localized: "%d times"), 2))
    }
}

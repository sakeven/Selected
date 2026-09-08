import Foundation
import Testing
@testable import Selected

struct ChatAttachmentTests {
    @Test func importsTextAsFileAndKeepsOriginalDocumentBytes() throws {
        var selection = ChatAttachments()
        try selection.append(ClipAIContent(text: "Hello 世界", images: [], files: []), filename: "notes.txt", openAI: true)
        let pdf = AIFileAttachment(filename: "report.pdf", data: Data("%PDF-original".utf8))
        try selection.append(ClipAIContent(text: "Excerpt", images: [], files: [pdf]), filename: "ignored", openAI: true)
        #expect(selection.files.map(\.attachment.filename) == ["notes.txt", "report.pdf"])
        #expect(selection.files[0].attachment.data == Data("Hello 世界".utf8))
        #expect(selection.files[0].attachment.mimeType == "text/plain")
        #expect(selection.files[1].attachment.data == pdf.data)
        #expect(selection.byteCount == Data("Hello 世界".utf8).count + pdf.data.count)
    }

    @Test func imagesTakePriorityOverTextAndDocumentRepresentations() throws {
        var selection = ChatAttachments()
        let image = Data([1, 2, 3])
        try selection.append(ClipAIContent(text: "OCR text", images: [image], files: [AIFileAttachment(filename: "ignored.pdf", data: Data([4]))]), filename: "image.png", openAI: false)
        try selection.appendImage(Data([5]), openAI: false)
        #expect(selection.images.map(\.data) == [image, Data([5])])
        #expect(selection.files.isEmpty)
        #expect(selection.byteCount == 4)
        #expect(selection.images[0].id != selection.images[1].id)
    }

    @Test(arguments: [false, true])
    func combinedBudgetRejectsExactLimitWithoutDroppingExistingAttachments(openAI: Bool) throws {
        var selection = ChatAttachments()
        let limit = openAI ? 50_000_000 : 23_000_000
        let file = AIFileAttachment(filename: "large.pdf", data: Data(count: limit - 2))
        try selection.append(ClipAIContent(text: "", images: [], files: [file]), filename: "large.pdf", openAI: openAI)
        try selection.appendImage(Data([1]), openAI: openAI)
        #expect(throws: ClipAIContent.ContentError.tooLarge) { try selection.appendImage(Data([2]), openAI: openAI) }
        #expect(selection.byteCount == limit - 1)
        #expect(selection.images.count == 1)
        #expect(selection.files.count == 1)
    }
}

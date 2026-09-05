import AppKit
import Foundation
import OpenAI
import PDFKit
import Testing
@testable import Selected

struct ClipboardAITests {
    @Test(arguments: ["docx", "xlsx", "pptx", "rtf", "odt", "pages", "key", "csv", "swift"])
    func openAISendsActualFileBytes(ext: String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID()).\(ext)")
        let bytes = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0xFF])
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let content = try ClipAIContent.load(items: [ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))], plainText: "filename only", openAI: true)
        let file = try #require(content.files.first)
        #expect(file.filename == url.lastPathComponent)
        #expect(file.data == bytes)
        let query = CreateModelResponseQuery(input: OpenAIProvider.messageInput(UserMessage(text: "Analyze", files: content.files)), model: .gpt5_6_sol)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(query)) as? [String: Any])
        let messages = try #require(json["input"] as? [[String: Any]])
        let parts = try #require(messages.first?["content"] as? [[String: Any]])
        let encoded = try #require(parts.first { $0["type"] as? String == "input_file" })
        #expect(encoded["filename"] as? String == url.lastPathComponent)
        #expect(encoded["file_data"] as? String == "data:\(file.mimeType);base64,\(bytes.base64EncodedString())")
    }

    @Test func preservesPDFPagesAndImages() throws {
        let buffer = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: buffer))
        var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1))
        context.fill(bounds)
        context.endPDFPage()
        context.closePDF()
        let pdf = buffer as Data
        for openAI in [true, false] {
            let content = try ClipAIContent.load(items: [ClipItem(type: .pdf, data: pdf)], plainText: "extracted text", openAI: openAI)
            #expect(content.files.first?.data == pdf)
            #expect(content.files.first?.mimeType == "application/pdf")
        }
    }

    @Test func imageContentTakesPriorityOverOCRText() throws {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let content = try ClipAIContent.load(items: [ClipItem(type: .png, data: png)], plainText: "OCR excerpt", openAI: true)
        #expect(content.images == [png])
        let input = OpenAIProvider.messageInput(UserMessage(text: "Read this", images: content.images))
        let query = CreateModelResponseQuery(input: input, model: .gpt6_astra)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(query)) as? [String: Any])
        let messages = try #require(json["input"] as? [[String: Any]])
        let parts = try #require(messages.first?["content"] as? [[String: Any]])
        let image = try #require(parts.first { $0["type"] as? String == "input_image" })
        #expect(image["image_url"] as? String == "data:image/png;base64,\(png.base64EncodedString())")
    }

    @Test func claudeEncodesPDFAndPNGWithCorrectTypes() throws {
        let pdf = Data("%PDF-test".utf8)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let content = try ClaudeAIProvider.messageContent(UserMessage(text: "Explain", images: [png], files: [AIFileAttachment(filename: "sample.pdf", data: pdf)]))
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try #require(JSONSerialization.jsonObject(with: encoder.encode(content)) as? [[String: Any]])
        #expect(json.count == 3)
        let document = try #require(json.first?["source"] as? [String: Any])
        #expect(document["media_type"] as? String == "application/pdf")
        #expect(document["data"] as? String == pdf.base64EncodedString())
        let image = try #require(json[1]["source"] as? [String: Any])
        #expect(image["media_type"] as? String == "image/png")
        #expect(json[2]["text"] as? String == "Explain")
    }

    @Test func claudeReadsTextFilesAndRejectsBinaryFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID()).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))
        try Data("Hello 世界".utf8).write(to: url)
        let content = try ClipAIContent.load(items: [item], plainText: nil, openAI: false)
        #expect(content.text.contains("Hello 世界"))
        try Data([0x50, 0x4B, 0x00, 0xFF]).write(to: url)
        #expect(throws: ClipAIContent.ContentError.unsupported) {
            try ClipAIContent.load(items: [item], plainText: nil, openAI: false)
        }
    }

    @Test func missingFileDoesNotSendOnlyItsName() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(ClipAIContent.kind(items: [ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))], plainText: "file name", openAI: true) == nil)
        #expect(throws: (any Error).self) {
            try ClipAIContent.load(items: [ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))], plainText: "file name", openAI: true)
        }
    }

    @Test(arguments: ["zip", "dmg", "exe", "mp4", "mov", "mp3", "wav", "new-format"])
    func unsupportedFilesHaveNoAIActions(ext: String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID()).\(ext)")
        try Data([0x50, 0x4B, 0x00, 0xFF]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))
        for openAI in [true, false] {
            #expect(ClipAIContent.kind(items: [item], plainText: "A filename is not file content", openAI: openAI) == nil)
            #expect(throws: ClipAIContent.ContentError.unsupported) {
                try ClipAIContent.load(items: [item], plainText: nil, openAI: openAI)
            }
        }
    }

    @Test(arguments: ["doc", "docx", "dot", "odt", "rtf", "pages", "pot", "ppa", "pps", "ppt", "pptx", "pwz", "wiz", "key", "xla", "xlb", "xlc", "xlm", "xls", "xlsx", "xlt", "xlw"])
    func officeDocumentsDependOnProvider(ext: String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID()).\(ext)")
        try Data([0x50, 0x4B, 0x00, 0xFF]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))
        #expect(ClipAIContent.kind(items: [item], plainText: nil, openAI: true) == .document)
        #expect(ClipAIContent.kind(items: [item], plainText: nil, openAI: false) == nil)
    }

    @Test func emptyFilesAndFoldersHaveNoAIActions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let emptyFile = folder.appendingPathComponent("empty.txt")
        try Data().write(to: emptyFile)
        for url in [folder, emptyFile] {
            let item = ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))
            #expect(ClipAIContent.kind(items: [item], plainText: "Copied file", openAI: true) == nil)
        }
    }

    @Test func contentKindsChooseRelevantActions() throws {
        #expect(ClipAIContent.kind(items: [], plainText: "Please polish this sentence.", openAI: true) == .text)
        #expect(ClipAIContent.kind(items: [], plainText: "{\"count\":1}", openAI: true) == .code)
        #expect(ClipAIContent.kind(items: [], plainText: "https://example.com", openAI: true) == .link)
        #expect(ClipAIContent.kind(items: [], plainText: "  \n  ", openAI: true) == nil)
        #expect(ClipAIContent.kind(items: [ClipItem(type: .color, data: Data([0]))], plainText: "#00FF00", openAI: true) == nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID()).swift")
        try Data("print(\"Hello\")".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ClipItem(type: .fileURL, data: Data(url.absoluteString.utf8))
        for openAI in [true, false] {
            #expect(ClipAIContent.kind(items: [item], plainText: nil, openAI: openAI) == .code)
        }
    }
}

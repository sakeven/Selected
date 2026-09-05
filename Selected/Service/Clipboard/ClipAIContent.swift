import AppKit
import PDFKit
import UniformTypeIdentifiers

struct ClipAIContent: Sendable {
    enum Kind {
        case text, code, link, image, document
    }

    var text: String
    var images: [Data] = []
    var files: [AIFileAttachment] = []

    enum ContentError: String, LocalizedError {
        case unsupported = "clip.ai.unsupported"
        case tooLarge = "clip.ai.tooLarge"
        case invalidImage = "clip.ai.invalidImage"
        case invalidPDF = "clip.ai.invalidPDF"
        case empty = "clip.ai.empty"

        var errorDescription: String? { NSLocalizedString(rawValue, comment: "") }
    }

    static func load(items: [ClipItem], plainText: String?, openAI: Bool) throws -> ClipAIContent {
        if let item = items.first(where: { $0.type == .fileURL }) {
            guard let value = String(data: item.data, encoding: .utf8),
                  let url = URL(string: value), url.isFileURL else {
                throw ContentError.unsupported
            }
            let resource = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentTypeKey])
            guard resource.isRegularFile == true else { throw ContentError.unsupported }
            guard (resource.fileSize ?? 0) < (openAI ? 50_000_000 : 23_000_000) else { throw ContentError.tooLarge }
            guard let kind = fileKind(url: url, contentType: resource.contentType, openAI: openAI) else {
                throw ContentError.unsupported
            }
            let data = try Data(contentsOf: url)
            if resource.contentType?.conforms(to: .pdf) == true {
                return try pdf(data, filename: url.lastPathComponent, openAI: openAI)
            }
            if kind == .image {
                return try image(data, name: url.lastPathComponent, openAI: openAI)
            }
            if openAI {
                let mimeType = resource.contentType?.preferredMIMEType ?? "application/octet-stream"
                return ClipAIContent(text: url.lastPathComponent, files: [AIFileAttachment(filename: url.lastPathComponent, data: data, mimeType: mimeType)])
            }
            let text: String?
            if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
                text = String(data: data, encoding: .utf16)
            } else {
                text = String(data: data, encoding: .utf8)
            }
            guard let text, !text.contains("\0") else { throw ContentError.unsupported }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ContentError.empty }
            return ClipAIContent(text: "\(url.lastPathComponent)\n\n\(text)")
        }
        if let item = items.first(where: { $0.type == .pdf }) {
            return try pdf(item.data, filename: "Clipboard.pdf", openAI: openAI)
        }
        if let item = items.first(where: { $0.type == .png }) ?? items.first(where: { $0.type == .tiff }) {
            return try image(item.data, name: String(localized: "Image"), openAI: openAI)
        }
        let text = plainText ?? items.first(where: { $0.type == .URL }).flatMap { String(data: $0.data, encoding: .utf8) } ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ContentError.empty }
        return ClipAIContent(text: text)
    }

    static func kind(items: [ClipItem], plainText: String?, openAI: Bool) -> Kind? {
        if let item = items.first(where: { $0.type == .fileURL }) {
            guard let value = String(data: item.data, encoding: .utf8),
                  let url = URL(string: value), url.isFileURL,
                  let resource = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey]),
                  resource.isRegularFile == true,
                  FileManager.default.isReadableFile(atPath: url.path),
                  let size = resource.fileSize, size > 0,
                  size < (openAI ? 50_000_000 : 23_000_000) else { return nil }
            return fileKind(url: url, contentType: resource.contentType, openAI: openAI)
        }
        if let item = items.first(where: { $0.type == .pdf }) {
            return item.data.isEmpty ? nil : .document
        }
        if let item = items.first(where: { $0.type == .png }) ?? items.first(where: { $0.type == .tiff }) {
            return item.data.isEmpty ? nil : .image
        }
        if items.contains(where: { $0.type == .color }) { return nil }
        let text = (plainText ?? items.first(where: { $0.type == .URL }).flatMap { String(data: $0.data, encoding: .utf8) } ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if JSONFormatter.isValidJSON(text) { return .code }
        if let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
           url.host != nil, text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return .link
        }
        return .text
    }

    private static func fileKind(url: URL, contentType: UTType?, openAI: Bool) -> Kind? {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp", "gif", "tif", "tiff", "bmp", "heic", "heif"].contains(ext) {
            return .image
        }
        if ext == "pdf" || contentType?.conforms(to: .pdf) == true { return .document }
        if ["csv", "tsv", "iif"].contains(ext) { return .document }

        // OpenAI file inputs: https://developers.openai.com/api/docs/guides/file-inputs
        let documentExtensions = Set("doc docx dot odt rtf pages pot ppa pps ppt pptx pwz wiz key xla xlb xlc xlm xls xlsx xlt xlw".split(separator: " ").map(String.init))
        if documentExtensions.contains(ext) { return openAI ? .document : nil }

        let codeExtensions = Set("asm bat c cc conf cpp css cxx def h hh htm html in js json ksh mjs pl py s sql xml ts tsx jsx swift rs go java kt kts rb sh bash zsh ps1 r jl lua php cs m mm scala dart ex exs erl hs clj groovy awk tex diff patch cmake ini properties proto sass scss less hcl tf toml graphql gql ndjson json5 yaml yml astro handlebars hbs mustache ejs jinja jinja2 liquid erb twig pug jade tmpl gradle".split(separator: " ").map(String.init))
        if codeExtensions.contains(ext) || contentType?.conforms(to: .sourceCode) == true
            || ["Dockerfile", "Makefile", "CMakeLists.txt", ".env", ".gitignore"].contains(url.lastPathComponent) {
            return .code
        }
        let textExtensions = Set("dic eml ics ifb list log markdown md mht mhtml mime nws rst srt text txt vcf vtt".split(separator: " ").map(String.init))
        if textExtensions.contains(ext) || contentType?.conforms(to: .plainText) == true { return .text }
        return nil
    }

    private static func pdf(_ data: Data, filename: String, openAI: Bool) throws -> ClipAIContent {
        guard data.count < (openAI ? 50_000_000 : 23_000_000) else { throw ContentError.tooLarge }
        guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
            throw ContentError.invalidPDF
        }
        return ClipAIContent(text: filename, files: [AIFileAttachment(filename: filename, data: data)])
    }

    private static func image(_ data: Data, name: String, openAI: Bool) throws -> ClipAIContent {
        guard let bitmap = NSBitmapImageRep(data: data) else {
            throw ContentError.invalidImage
        }
        let encoded: Data
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) || data.starts(with: [0xFF, 0xD8]) {
            encoded = data
        } else {
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ContentError.invalidImage }
            encoded = png
        }
        guard encoded.count < (openAI ? 50_000_000 : 5_000_000) else { throw ContentError.tooLarge }
        return ClipAIContent(text: name, images: [encoded])
    }

}

extension ClipHistoryData {
    func aiContentKind(openAI: Bool) -> ClipAIContent.Kind? {
        let items = getItems().compactMap { item -> ClipItem? in
            guard let type = item.type, let data = item.data else { return nil }
            return ClipItem(type: NSPasteboard.PasteboardType(type), data: data)
        }
        return ClipAIContent.kind(items: items, plainText: plainText, openAI: openAI)
    }

    var hasAIAttachment: Bool {
        let types: Set<String> = [NSPasteboard.PasteboardType.fileURL.rawValue, NSPasteboard.PasteboardType.pdf.rawValue,
                                  NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue]
        return getItems().contains { types.contains($0.type ?? "") }
    }
}

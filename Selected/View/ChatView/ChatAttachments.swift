import Foundation

struct ChatAttachments {
    struct Image: Identifiable {
        let id = UUID()
        let data: Data
    }

    struct File: Identifiable {
        let id = UUID()
        let attachment: AIFileAttachment
    }

    var images: [Image] = []
    var files: [File] = []

    var byteCount: Int {
        images.reduce(0) { $0 + $1.data.count } + files.reduce(0) { $0 + $1.attachment.data.count }
    }

    mutating func append(_ content: ClipAIContent, filename: String, openAI: Bool) throws {
        let addedFiles = content.images.isEmpty
            ? (content.files.isEmpty ? [AIFileAttachment(filename: filename, data: Data(content.text.utf8), mimeType: "text/plain")] : content.files)
            : []
        let addedBytes = content.images.reduce(0) { $0 + $1.count } + addedFiles.reduce(0) { $0 + $1.data.count }
        try validate(addedBytes: addedBytes, openAI: openAI)
        images += content.images.map { Image(data: $0) }
        files += addedFiles.map { File(attachment: $0) }
    }

    mutating func appendImage(_ data: Data, openAI: Bool) throws {
        try validate(addedBytes: data.count, openAI: openAI)
        images.append(Image(data: data))
    }

    private func validate(addedBytes: Int, openAI: Bool) throws {
        guard byteCount + addedBytes < (openAI ? 50_000_000 : 23_000_000) else {
            throw ClipAIContent.ContentError.tooLarge
        }
    }
}

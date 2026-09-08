import Foundation

public struct ChatContext {
    let text: String
    let webPageURL: String
    let bundleID: String
    let images: [Data]
    let files: [AIFileAttachment]
    let request: String?
    let clipboardText: String

    init(text: String, webPageURL: String, bundleID: String, images: [Data] = [], files: [AIFileAttachment] = [], request: String? = nil, clipboardText: String = "") {
        self.text = text
        self.webPageURL = webPageURL
        self.bundleID = bundleID
        self.images = images
        self.files = files
        self.request = request
        self.clipboardText = clipboardText
    }

    func message(prompt: String, options: [String: String]) -> UserMessage {
        var content = renderChatContent(content: prompt, chatCtx: self, options: options)
        content = replaceOptions(content: content, selectedText: text, options: options)
        if let request {
            content = "\(request)\n\n\(content)"
        }
        return UserMessage(text: content, images: images, files: files)
    }
}

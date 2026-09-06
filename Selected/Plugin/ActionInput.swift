import AppKit
import Defaults

struct ActionInput {
    var context: SelectedTextContext
    var items: [ClipItem] = []
    var reference: String? { context.ClipboardText }

    init(context: SelectedTextContext) {
        self.context = context
    }

    init(clip: ClipHistoryData) {
        context = Self.textContext(clip.plainText ?? "", bundleID: clip.application ?? "", webPageURL: clip.hasAIAttachment ? "" : clip.url ?? "")
        items = clip.getItems().compactMap {
            guard let type = $0.type, let data = $0.data else { return nil }
            return ClipItem(type: NSPasteboard.PasteboardType(rawValue: type), data: data)
        }
    }

    var kind: ClipAIContent.Kind? {
        ClipAIContent.kind(items: items, plainText: context.Text, openAI: Defaults[.aiService] == "OpenAI")
    }

    var hasAttachment: Bool {
        items.contains { [.fileURL, .pdf, .png, .tiff].contains($0.type) }
    }

    func loadContent() async throws -> ClipAIContent {
        let items = items, text = context.Text, openAI = Defaults[.aiService] == "OpenAI"
        return try await Task.detached {
            try ClipAIContent.load(items: items, plainText: text, openAI: openAI)
        }.value
    }

    func replacingText(_ text: String) -> ActionInput {
        ActionInput(context: Self.textContext(text, bundleID: context.BundleID, webPageURL: context.WebPageURL))
    }

    static func textContext(_ text: String, bundleID: String = "", webPageURL: String = "") -> SelectedTextContext {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { $0.url?.absoluteString } ?? []
        return SelectedTextContext(Text: text, BundleID: bundleID, WebPageURL: webPageURL, URLs: links)
    }
}

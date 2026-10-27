import Foundation
import OpenAI
import Testing
@testable import Selected

struct AIRequestsTests {
    @Test func chatAndTranslationUseOpenAI() {
        #expect(ChatService(prompt: "", options: [:]).chatService is OpenAIProvider)
        #expect(Translation.TranslateService(prompt: "").chatService is OpenAIProvider)
    }

    @Test func initialPromptPreservesTemplateOrderAndAttachments() {
        let image = Data([0x89, 0x50, 0x4E, 0x47])
        let file = AIFileAttachment(filename: "notes.txt", data: Data("File text".utf8), mimeType: "text/plain")
        let context = ChatContext(text: "Hello {selected.options.language}", webPageURL: "https://example.com", bundleID: "app.test", images: [image], files: [file], request: "Translate", clipboardText: "Clipboard")
        let message = context.message(prompt: "{{ selected.text }} | {selected.text} | {{ options.language }} | {{ selected.clipboardText }}", options: ["language": "中文"])
        #expect(message.text == "Translate\n\nHello 中文 | Hello 中文 | 中文 | Clipboard")
        #expect(message.images == [image])
        #expect(message.files.first?.filename == file.filename)
        #expect(message.files.first?.data == file.data)
    }

    @Test func absentAndEmptyRequestsKeepTheirDistinctFormatting() {
        let absent = ChatContext(text: "Hello", webPageURL: "", bundleID: "")
        let empty = ChatContext(text: "Hello", webPageURL: "", bundleID: "", request: "")
        #expect(absent.message(prompt: "{selected.text}", options: [:]).text == "Hello")
        #expect(empty.message(prompt: "{selected.text}", options: [:]).text == "\n\nHello")
    }

    @Test func openAIContinuationRetainsConversationSettings() throws {
        let original = CreateModelResponseQuery(input: .textInput("old"), model: .gpt6_astra, instructions: "System", previousResponseId: "old-id", reasoning: .init(effort: .high, summary: .auto), stream: true, text: .text, tools: [.webSearchTool(.init(_type: .webSearch))])
        let continued = original.continuing(with: .textInput("follow up"), previousResponseID: "new-id")
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(continued)) as? [String: Any])
        #expect(json["input"] as? String == "follow up")
        #expect(json["model"] as? String == "gpt-6-astra")
        #expect(json["instructions"] as? String == "System")
        #expect(json["previous_response_id"] as? String == "new-id")
        #expect(json["stream"] as? Bool == true)
        #expect((json["reasoning"] as? [String: Any])?["effort"] as? String == "high")
        #expect((json["tools"] as? [[String: Any]])?.count == 1)
        #expect(json["text"] == nil)
        #expect(original.previousResponseId == "old-id")
        #expect(original.continuing(with: original.input, previousResponseID: nil).previousResponseId == nil)
    }

    @Test(arguments: ["", "word", "well-known", "中文", "café", "---"])
    func wordClassificationKeepsExistingAcceptedInputs(text: String) {
        #expect(isWord(str: text))
    }

    @Test(arguments: ["two words", "word!", "123", "a_b", "🙂", "line\nbreak"])
    func wordClassificationKeepsExistingRejectedInputs(text: String) {
        #expect(!isWord(str: text))
    }

    @Test func unsupportedTranslationLanguageDoesNotEmitOutput() async {
        var output: [String] = []
        await Translation(toLanguage: "fr").translate(content: "Hello") { output.append($0) }
        #expect(output.isEmpty)
    }
}

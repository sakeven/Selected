import Foundation
import Testing
@testable import Selected

@MainActor
struct ChatMessagesTests {
    @Test func sentFilesRemainVisibleAndReachProvider() async {
        let provider = ChatTestProvider(events: [.begin("reply"), .textDelta("Partial reply")])
        let model = MessageViewModel(chatService: provider)
        let file = AIFileAttachment(filename: "report.pdf", data: Data("%PDF-test".utf8))
        await model.submit(message: UserMessage(text: "Summarize", files: [file]))
        #expect(provider.received?.files.first?.data == file.data)
        #expect(model.messages.dropLast().last?.files.first?.filename == "report.pdf")
        #expect(model.messages.last?.message == "Partial reply")
        #expect(model.messages.last?.status == .finished)
        #expect(!model.inProgress)
    }

    @Test func firstResponseErrorsHaveFailureAppearance() async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: [.error("Could not read the file")]))
        await model.fetchMessages(ctx: ChatContext(text: "", webPageURL: "", bundleID: ""))
        #expect(model.messages.last?.status == .failure)
        #expect(model.messages.last?.role == .system)
        #expect(!model.inProgress)
    }

    @Test(arguments: [false, true])
    func stoppingReplyPreservesPartialText(isFirstReply: Bool) async {
        let provider = ChatTestProvider(events: [.begin("reply"), .textDelta("Partial reply")], finishesStream: false)
        let model = MessageViewModel(chatService: provider)
        let task = Task {
            if isFirstReply {
                await model.fetchMessages(ctx: ChatContext(text: "Summarize", webPageURL: "", bundleID: ""))
            } else {
                await model.submit(message: UserMessage(text: "Summarize"))
            }
        }
        for _ in 0..<100 {
            if model.messages.last?.message == "Partial reply" { break }
            try? await Task.sleep(for: .milliseconds(2))
        }
        let wasStreaming = model.inProgress && model.messages.last?.status == .updating
        task.cancel()
        await task.value
        #expect(wasStreaming)
        #expect(model.messages.last?.message == "Partial reply")
        #expect(model.messages.last?.role == .assistant)
        #expect(model.messages.last?.status == .finished)
        #expect(!model.inProgress)
    }

    @Test func claudeEncodesImportedTextFilesAsText() throws {
        let file = AIFileAttachment(filename: "notes.txt", data: Data("notes.txt\n\nHello 世界".utf8), mimeType: "text/plain")
        let content = try ClaudeAIProvider.messageContent(UserMessage(text: "Summarize", files: [file]))
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(content)) as? [[String: Any]])
        #expect(json[0]["type"] as? String == "text")
        #expect(json[0]["text"] as? String == "notes.txt\n\nHello 世界")
        #expect(json[1]["text"] as? String == "Summarize")
    }
}

private final class ChatTestProvider: AIProvider {
    let events: [AIStreamEvent]
    let finishesStream: Bool
    var received: UserMessage?

    init(events: [AIStreamEvent], finishesStream: Bool = true) {
        self.events = events
        self.finishesStream = finishesStream
    }

    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            if finishesStream { continuation.finish() }
        }
    }

    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> {
        chatOnce(selectedText: ctx.text)
    }

    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error> {
        received = userMessage
        return chatOnce(selectedText: userMessage.text)
    }
}

import Foundation
import Testing
@testable import Selected

@MainActor
struct ChatMessagesTests {
    @Test(arguments: [false, true])
    func completedTextReplacesDeltasAndReasoningKeepsSectionBreaks(isFirstReply: Bool) async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: [
            .begin("first"), .textDelta("草稿"), .textDelta("。"),
            .reasoningDelta("思考"), .reasoningDone("不会重复追加"),
            .reasoningDelta("继续"), .reasoningDone(""),
            .textDone("**最终答案。**后续"), .done
        ]))
        await respond(model, isFirstReply: isFirstReply)
        #expect(model.messages.last?.message == "**最终答案。**后续")
        #expect(model.messages.last?.summary == "思考\n\n继续\n\n")
        #expect(model.messages.last?.role == .assistant)
        #expect(model.messages.last?.status == .finished)
        #expect(!model.inProgress)
    }

    @Test(arguments: [false, true])
    func toolUpdatesPreserveMetadataAndDeduplicateSources(isFirstReply: Bool) async throws {
        let first = AIToolSourceLink(title: "First", url: "https://example.com/one")
        let second = AIToolSourceLink(title: "Second", url: "https://example.com/two")
        let model = MessageViewModel(chatService: ChatTestProvider(events: [
            .begin("reply"),
            .toolCallUpdated(.init(id: "missing", sourceLinks: [first])),
            .toolCallStarted(.init(id: "b", name: "command", message: "running", arguments: "{}", command: "echo test", workdir: "/tmp", sourceLinks: [first])),
            .toolCallUpdated(.init(id: "b", sourceLinks: [first, second])),
            .toolCallFinished(.init(id: "b", name: "command", ret: "result", arguments: nil, command: nil, workdir: nil, sourceLinks: [second])),
            .toolCallStarted(.init(id: "a", name: "search", message: "searching", arguments: nil, command: nil, workdir: nil, sourceLinks: [])),
            .textDone("Answer"), .done
        ]))
        await respond(model, isFirstReply: isFirstReply)
        let message = try #require(model.messages.last)
        let tool = try #require(message.tools["b"])
        #expect(tool.ret == "result")
        #expect(tool.status == .success)
        #expect(tool.arguments == "{}")
        #expect(tool.command == "echo test")
        #expect(tool.workdir == "/tmp")
        #expect(tool.sourceLinks == [first, second])
        #expect(message.tools["missing"] == nil)
        #expect(message.items.map(\.key) == ["a", "b"])
        #expect(message.tools["a"]?.status == .calling)
    }

    @Test(arguments: [false, true])
    func streamErrorsKeepFailureStateAfterPartialOutput(isFirstReply: Bool) async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: [
            .begin("reply"), .textDelta("Partial"), .error("tooManyToolLoops"), .done
        ]))
        await respond(model, isFirstReply: isFirstReply)
        #expect(model.messages.last?.role == .system)
        #expect(model.messages.last?.status == .failure)
        #expect(model.messages.last?.message == "tooManyToolLoops")
        #expect(!model.inProgress)
    }

    @Test(arguments: [false, true])
    func thrownErrorsReplacePartialOutput(isFirstReply: Bool) async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: [.begin("reply"), .textDelta("Partial")], error: ChatTestError()))
        await respond(model, isFirstReply: isFirstReply)
        #expect(model.messages.last?.role == .system)
        #expect(model.messages.last?.status == .failure)
        #expect(model.messages.last?.message == "fixture failure")
        #expect(!model.inProgress)
    }

    @Test(arguments: [false, true])
    func newRoundsKeepExistingFirstAndFollowupBehavior(isFirstReply: Bool) async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: [
            .begin("first"), .textDelta("First"), .begin("second"), .textDelta("Second")
        ]))
        await respond(model, isFirstReply: isFirstReply)
        #expect(model.messages.last?.message == (isFirstReply ? "Second" : "FirstSecond"))
        #expect(model.messages.last?.status == .finished)
    }

    @Test(arguments: [false, true])
    func emptyStreamsKeepExistingPlaceholderBehavior(isFirstReply: Bool) async {
        let model = MessageViewModel(chatService: ChatTestProvider(events: []))
        await respond(model, isFirstReply: isFirstReply)
        #expect(model.messages.last?.role == (isFirstReply ? .system : .assistant))
        #expect(model.messages.last?.status == (isFirstReply ? .initial : .finished))
        #expect(!model.inProgress)
    }

    private func respond(_ model: MessageViewModel, isFirstReply: Bool) async {
        if isFirstReply {
            await model.fetchMessages(ctx: ChatContext(text: "Question", webPageURL: "", bundleID: ""))
        } else {
            await model.submit(message: UserMessage(text: "Question"))
        }
    }

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
    let error: Error?
    var received: UserMessage?

    init(events: [AIStreamEvent], finishesStream: Bool = true, error: Error? = nil) {
        self.events = events
        self.finishesStream = finishesStream
        self.error = error
    }

    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            if finishesStream { continuation.finish(throwing: error) }
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

private struct ChatTestError: LocalizedError {
    var errorDescription: String? { "fixture failure" }
}

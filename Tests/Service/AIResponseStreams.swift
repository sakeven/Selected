import Foundation
import OpenAI
import Testing
@testable import Selected

struct AIResponseStreamsTests {
    @Test func openAITextAndReasoningFramesKeepOrder() async throws {
        let state = OpenAIResponseState()
        let events = [
            #"{"type":"response.output_text.delta","item_id":"msg","output_index":0,"content_index":0,"sequence_number":1,"logprobs":[],"delta":"Hello"}"#,
            #"{"type":"response.reasoning_summary_text.delta","item_id":"reason","output_index":0,"summary_index":0,"sequence_number":2,"delta":"Think"}"#,
            #"{"type":"response.reasoning_summary_text.done","item_id":"reason","output_index":0,"summary_index":0,"sequence_number":3,"text":"Thinking"}"#,
            #"{"type":"response.output_text.done","item_id":"msg","output_index":0,"content_index":0,"sequence_number":4,"logprobs":[],"text":"Hello 世界"}"#
        ]
        let stream = AsyncThrowingStream<AIStreamEvent, Error>.makeStream()
        for json in events {
            try state.handleResponseStreamEvent(JSONDecoder().decode(ResponseStreamEvent.self, from: Data(json.utf8)), continuation: stream.continuation)
        }
        stream.continuation.finish()
        let output = try await descriptions(stream.stream)
        #expect(output == ["text:Hello", "reasoning:Think", "reasoningDone:Thinking", "textDone:Hello 世界"])
        #expect(!state.hasToolsCalled)
    }

    @Test func openAIFunctionCallsUseCallIDAndKeepFinalArguments() throws {
        let state = OpenAIResponseState()
        let stream = AsyncThrowingStream<AIStreamEvent, Error>.makeStream()
        defer { stream.continuation.finish() }
        let json = #"{"type":"response.output_item.done","output_index":0,"sequence_number":1,"item":{"id":"item-id","type":"function_call","call_id":"call-id","name":"lookup","arguments":"{\"query\":\"世界\"}","status":"completed"}}"#
        try state.handleResponseStreamEvent(.outputItem(.done(JSONDecoder().decode(ResponseOutputItemDoneEvent.self, from: Data(json.utf8)))), continuation: stream.continuation)
        #expect(state.hasToolsCalled)
        #expect(state.toolCallsDict.count == 1)
        #expect(state.toolCallsDict["call-id"]?.id == "call-id")
        #expect(state.toolCallsDict["call-id"]?.name == "lookup")
        #expect(state.toolCallsDict["call-id"]?.arguments == #"{"query":"世界"}"#)
    }

    @Test func openAIWebSearchAnnotationsStayWithLatestSearch() async throws {
        let state = OpenAIResponseState()
        let stream = AsyncThrowingStream<AIStreamEvent, Error>.makeStream()
        let events = [
            #"{"type":"response.output_text.annotation.added","item_id":"msg","output_index":0,"content_index":0,"annotation_index":0,"sequence_number":1,"annotation":{"type":"url_citation","title":"Ignored","url":"https://example.com/ignored","start_index":0,"end_index":1}}"#,
            #"{"type":"response.web_search_call.in_progress","item_id":"search-1","output_index":0,"sequence_number":2}"#,
            #"{"type":"response.web_search_call.completed","item_id":"search-1","output_index":0,"sequence_number":3}"#,
            #"{"type":"response.web_search_call.in_progress","item_id":"search-2","output_index":1,"sequence_number":4}"#,
            #"{"type":"response.output_text.annotation.added","item_id":"msg","output_index":0,"content_index":0,"annotation_index":0,"sequence_number":5,"annotation":{"type":"url_citation","title":"Source","url":"https://example.com/source","start_index":0,"end_index":1}}"#
        ]
        for json in events {
            try state.handleResponseStreamEvent(JSONDecoder().decode(ResponseStreamEvent.self, from: Data(json.utf8)), continuation: stream.continuation)
        }
        stream.continuation.finish()
        var starts: [String] = []
        var finishes: [String] = []
        var updates: [ToolCallUpdate] = []
        for try await event in stream.stream {
            if case .toolCallStarted(let start) = event { starts.append(start.id) }
            if case .toolCallFinished(let result) = event { finishes.append(result.id) }
            if case .toolCallUpdated(let update) = event { updates.append(update) }
        }
        #expect(starts == ["search-1", "search-2"])
        #expect(finishes == ["search-1"])
        #expect(updates.count == 1)
        #expect(updates.first?.id == "search-2")
        #expect(updates.first?.sourceLinks == [.init(title: "Source", url: "https://example.com/source")])
    }

    private func descriptions(_ stream: AsyncThrowingStream<AIStreamEvent, Error>) async throws -> [String] {
        var output: [String] = []
        for try await event in stream {
            switch event {
            case .textDelta(let text): output.append("text:\(text)")
            case .textDone(let text): output.append("textDone:\(text)")
            case .reasoningDelta(let text): output.append("reasoning:\(text)")
            case .reasoningDone(let text): output.append("reasoningDone:\(text)")
            default: Issue.record("Unexpected response event")
            }
        }
        return output
    }
}

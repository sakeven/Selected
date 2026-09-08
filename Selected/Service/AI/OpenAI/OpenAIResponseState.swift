import Foundation
import OpenAI

final class OpenAIResponseState {
    public var lastOpenAIResponseId: String?
    public var toolCallsDict: [String: FunctionCallParam]
    private var lastWebSearchCallId: String?
    public var hasToolsCalled: Bool {
        get {
            !toolCallsDict.isEmpty
        }
    }

    public init() {
        self.toolCallsDict = [String: FunctionCallParam]()
    }

    func handleResponseStreamEvent(_ event: ResponseStreamEvent, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation ) throws {
        switch event {
            case .created(let responseEvent):
                continuation.yield(.begin(responseEvent.response.id))
                lastOpenAIResponseId = responseEvent.response.id
            case .inProgress(_ /* let responseInProgressEvent */):
                break
            case .outputItem(let outputItemEvent):
                try handleOutputItemEvent(outputItemEvent, continuation: continuation)
            case .functionCallArguments(_):
                break
            case .contentPart(.added(_)):
                break
            case .outputText(let outputTextEvent):
                try handleOutputTextEvent(outputTextEvent, continuation: continuation)
            case .contentPart(.done(_)):
                break
            case .completed(_ /* let responseEvent */):
                // # 29
                break
            case .queued(_ /* let responseEvent */):
                // Response is queued - no action needed
                break
            case .failed(_ /* let responseEvent */):
                // Response failed - could show error in UI
                AppLogger.ai.debug("Response failed")
                break
            case .incomplete(_ /* let responseEvent */):
                // Response incomplete - could show warning in UI
                AppLogger.ai.debug("Response incomplete")
                break
            case .error(let errorEvent):
                // Error event - log the error
                AppLogger.ai.debug("Response error: \(String(describing:errorEvent))")
                break
            case .refusal(let refusalEvent):
                // Refusal event - handle refusal
                AppLogger.ai.debug("Response refusal: \(String(describing:refusalEvent))")
                break
            case .outputTextAnnotation(let annotationEvent):
                switch annotationEvent {
                    case .added(let event):
                        guard let toolCallID = lastWebSearchCallId else { break }
                        if case let .UrlCitationBody(citation) = event.annotation {
                            continuation.yield(.toolCallUpdated(.init(
                                id: toolCallID,
                                sourceLinks: [.init(title: citation.title, url: citation.url)]
                            )))
                        }
                }
            case .reasoning(let reasoningEvent):
                // Handle reasoning events - could show reasoning in UI
                switch reasoningEvent {
                    case .delta(let event):
                        AppLogger.ai.debug("Reasoning delta event received \(event.itemId) \(event.delta)")
                    case .done(let event):
                        AppLogger.ai.debug("Reasoning done event received \(event.itemId) \(event.text)")
                }
            case .reasoningSummary(let reasoningSummaryEvent):
                // Handle reasoning summary events
                switch reasoningSummaryEvent {
                    case .delta(let event):
                        AppLogger.ai.debug("Reasoning summary delta event received \(event.itemId) \(event.delta)")
                    case .done(let event):
                        AppLogger.ai.debug("Reasoning summary done event received \(event.itemId) \(event.text)")
                }
            case .audio(_ /* let audioEvent */):
                // Audio events - not implemented yet
                AppLogger.ai.debug("Audio event received (not implemented)")
                break
            case .audioTranscript(_ /* let audioTranscriptEvent */):
                // Audio transcript events - not implemented yet
                AppLogger.ai.debug("Audio transcript event received (not implemented)")
                break
            case .codeInterpreterCall(_ /* let codeInterpreterCallEvent */):
                // Code interpreter events - not implemented yet
                AppLogger.ai.debug("Code interpreter call event received (not implemented)")
                break
            case .fileSearchCall(_ /* let fileSearchCallEvent */):
                // File search events - not implemented yet
                AppLogger.ai.debug("File search call event received (not implemented)")
                break
            case .imageGenerationCall(_ /* let imageGenerationCallEvent */):
                // Image generation events - not implemented yet
                AppLogger.ai.debug("Image generation call event received (not implemented)")
                break
            case .reasoningSummaryPart( let reasoningSummaryPartEvent):
                switch reasoningSummaryPartEvent {
                    case .added(let delta):
                        AppLogger.ai.debug("Reasoning summary part delta event received \(delta.itemId) \(delta.part.text)")
                    case .done(let done):
                        AppLogger.ai.debug("Reasoning summary part done event received \(done.itemId) \(done.part.text)")
                        break
                }
                break
            case .reasoningSummaryText(let reasoningSummaryTextEvent):
                switch reasoningSummaryTextEvent {
                    case .delta(let delta):
                        //                        print("Reasoning summary text delta event received \(delta.itemId) \(delta.delta)")
                        continuation.yield(.reasoningDelta(delta.delta))
                    case .done(let done):
                        //                        print("Reasoning summary text done event received \(done.itemId) \(done.text)")
                        continuation.yield(.reasoningDone(done.text))
                }
                break
            case .webSearchCall(let webSearchCall):
                switch webSearchCall {
                    case .inProgress(let webSearch):
                        lastWebSearchCallId = webSearch.itemId
                        continuation.yield(.toolCallStarted(.init(
                            id: webSearch.itemId,
                            name: String(localized:  "Web search"),
                            message: String(localized: "in progress"),
                            arguments: nil,
                            command: nil,
                            workdir: nil,
                            sourceLinks: []
                        )))
                    case .searching(_):
                        break
                    case .completed(let webSearch):
                        continuation.yield(.toolCallFinished(.init(
                            id: webSearch.itemId,
                            name: String(localized:  "Web search"),
                            ret: String(localized: "completed"),
                            arguments: nil,
                            command: nil,
                            workdir: nil,
                            sourceLinks: []
                        )))
                }
                break
            case .mcpCall(_):
                break
            case .mcpCallArguments(_):
                break
            case .mcpListTools(_):
                break
            case .customToolCall(_):
                break
            case .keepalive:
                break
        }
    }

    private func handleOutputItemEvent(_ event: ResponseStreamEvent.OutputItemEvent, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) throws {
        switch event {
            case .added(let outputItemAddedEvent):
                try handleOutputItemAdded(outputItemAddedEvent.item, continuation: continuation)
            case .done(let outputItemDoneEvent):
                try handleOutputItemDone(outputItemDoneEvent.item, continuation: continuation)
        }
    }

    private func handleOutputItemAdded(_ outputItem: OutputItem, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation ) throws {
        switch outputItem {
            case .OutputMessage(_):
                continuation.yield(.textDelta(""))
            case .WebSearchToolCall(_ /* let webSearchToolCall */):
                break
            case .FunctionToolCall(_):
                break
            case .MCPApprovalRequest(_ /*let approvalRequest*/):
                break
            case .MCPListTools(_ /* let mcpListTools */):
                // MCP tools listed - no UI action needed
                break
            case .MCPToolCall(_ /* let mcpCall */):
                // MCP tool call in progress - no UI action needed
                break
            default:
                break
        }
    }

    private func handleOutputItemDone(_ outputItem: OutputItem, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) throws {
        switch outputItem {
            case .OutputMessage(let outputMessage):
                for content in outputMessage.content {
                    switch content {
                        case .OutputTextContent(let outputText):
                            continuation.yield(.textDone(outputText.text))
                            // message.annotations = outputText.annotations
                        case .RefusalContent(_):
                            break
                            // message.refusalText = refusal.refusal
                    }
                }
            case .WebSearchToolCall(_ /* let webSearchToolCall */):
                break
            case .FunctionToolCall(let functionToolCall):
                toolCallsDict[functionToolCall.callId] = FunctionCallParam(id: functionToolCall.callId, name: functionToolCall.name, arguments: functionToolCall.arguments)
                break
            case .MCPApprovalRequest(_ /* let approvalRequest */):
                // MCP approval request completed - no additional action needed
                break
            case .MCPListTools(_ /* let mcpListTools */):
                // MCP tools listing completed - no additional action needed
                break
            case .MCPToolCall(_):
                break
            default:
                break
        }
    }


    private func handleOutputTextEvent(_ outputTextEvent: ResponseStreamEvent.OutputTextEvent, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) throws {
        switch outputTextEvent {
            case .delta(let responseTextDeltaEvent):
                continuation.yield(.textDelta(responseTextDeltaEvent.delta))
                // Note: Annotations are now handled via separate outputTextAnnotation events
            case .done(let responseTextDoneEvent):
                continuation.yield(.textDone(responseTextDoneEvent.text))
        }
    }
}

struct FunctionCallParam {
    public var id: String
    public var name: String
    public var arguments: String
}

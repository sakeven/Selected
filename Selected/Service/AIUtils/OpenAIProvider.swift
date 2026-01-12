//
//  OpenAI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import OpenAI
import Defaults
import SwiftUI
import AVFoundation


typealias OpenAIModel = Model

extension Model {
    static let gpt5_2 = "gpt-5.2"
    static let gpt5_2_pro = "gpt-5.2-pro"
    static let gpt5_pro = "gpt-5-pro"
}

let OpenAIModels: [Model] = [
    .gpt5_2, .gpt5_2_pro,
    .gpt5_1,
    .gpt5_mini, .gpt5,
    .gpt5_pro,
    .gpt4_1, .gpt4_1_mini, .o4_mini,
    .o3, .gpt4_o, .gpt4_o_mini, .o3_mini]
let OpenAITTSModels: [Model] = [.gpt_4o_mini_tts, .tts_1, .tts_1_hd]
let OpenAITranslationModels: [Model] = [.gpt5_1, .gpt4_1_mini, .gpt4_o, .gpt4_o_mini]

typealias OpenAIModelReasoningEffort = Components.Schemas.ReasoningEffort
let OpenAIReasoningEfforts = Components.Schemas.ReasoningEffort.allCases

func isReasoningModel(_ model: Model) -> Bool {
    return [.gpt5_2, .gpt5_2_pro, .gpt5_mini, .gpt5, .gpt5_1, .gpt5_pro, .o4_mini, .o3, .o1, .o3_mini].contains(model)
}


extension OpenAIModel {
    var supportedReasoningEfforts: [OpenAIModelReasoningEffort] {
        if !isReasoningModel(self){
            return []
        }
        switch self {
            case .gpt5_pro:
                return [.high]
            case .gpt5:
                return [.low, .medium, .high]
            case .gpt5_1:
                return [.none, .low, .medium, .high]
            case .gpt5_2, .gpt5_2_pro:
                return [.none, .low, .medium, .high, .xhigh]
            default:
                return [.low, .medium, .high]
        }
    }

    var supportsReasoningEffort: Bool {
        !supportedReasoningEfforts.isEmpty
    }
}

let dalle3Def = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "Dall-E-3",
    description: "When user asks for a picture, create a prompt that dalle can use to generate the image. The prompt must be in English. Translate to English if needed. The url of the image will be returned.",
    parameters:
            .init(
                fields: [
                    .type(.object),
                    .properties(
                        [
                            "prompt":
                                    .init(
                                        fields: [
                                            .type( .string),
                                            .description( "the generated prompt sent to dalle3"),
                                        ]
                                    )
                        ]
                    )
                ]
            )
)

final class MiddleWare: OpenAIMiddleware {
    func intercept(response: URLResponse?, request: URLRequest, data: Data?) -> (response: URLResponse?, data: Data?) {
        if let data = data {
            print(String(data: data, encoding: .utf8) ?? "no data")
        } else {
            AppLogger.ai.debug("no data")
        }
        return (response, data)
    }
}

class OpenAIProvider: AIProvider{
    private let prompt: String
    private var tools: [FunctionDefinition]?
    private let openAI: OpenAI
    private var responseQuery: CreateModelResponseQuery
    private var options: [String: String]

    // 初始化时传入 prompt、工具列表和其他选项
    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:], reasoning: Bool = true) {
        self.prompt = prompt
        self.tools = tools
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey], host: host, timeoutInterval: 60.0, parsingOptions: .relaxed)
        self.openAI = OpenAI(configuration: configuration, middlewares: [MiddleWare()])
        self.options = options
        self.responseQuery = OpenAIProvider.createResponseQuery(functions: tools, model: Defaults[.openAIModel], thinking: reasoning)
    }

    // 初始化时直接传入 prompt 和模型
    init(prompt: String, model: OpenAIModel, reasoning: Bool = true) {
        self.prompt = prompt
        self.tools = nil
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey], host: host, timeoutInterval: 60.0)
        self.openAI = OpenAI(configuration: configuration)
        self.options = [:]
        self.responseQuery = OpenAIProvider.createResponseQuery(functions: tools, model: model, thinking: reasoning)
    }

    // 更新对话查询
    private func updateQuery(message: String) {
        responseQuery = CreateModelResponseQuery(
            input: .textInput(message),
            model: responseQuery.model,
            instructions: responseQuery.instructions,
            previousResponseId: responseQuery.previousResponseId,
            reasoning: responseQuery.reasoning,
            stream: true,
            tools: responseQuery.tools,
        )
    }

    private func updateQuery(message: UserMessage) {
        var inputItems = [InputContent]()
        inputItems.append(.inputText(.init(_type: .inputText, text: message.text)))
        for image in message.images {
            inputItems.append(.inputImage(.init(imageData: image, detail: .auto)))
        }
        let input = CreateModelResponseQuery.Input.inputItemList([
            .inputMessage(.init(role: .user, content: .inputItemContentList(inputItems)))
        ])
        responseQuery = CreateModelResponseQuery(
            input: input,
            model: responseQuery.model,
            instructions: responseQuery.instructions,
            previousResponseId: responseQuery.previousResponseId,
            reasoning: responseQuery.reasoning,
            stream: true,
            tools: responseQuery.tools,
        )
    }

    private func updateQuery(lastResponseId: String) {
        responseQuery = CreateModelResponseQuery(
            input: responseQuery.input,
            model: responseQuery.model,
            instructions: responseQuery.instructions,
            previousResponseId: lastResponseId,
            reasoning: responseQuery.reasoning,
            stream: true,
            tools: responseQuery.tools,
        )
    }

    private func updateQueryWithToolOutput(lastResponseId: String, input: CreateModelResponseQuery.Input) {
        responseQuery = CreateModelResponseQuery(
            input: input,
            model: responseQuery.model,
            instructions: responseQuery.instructions,
            previousResponseId: lastResponseId,
            reasoning: responseQuery.reasoning,
            stream: true,
            tools: responseQuery.tools,
        )
    }

    /// 单轮对话，适合简单返回结果（流式返回）
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let messageContent = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        updateQuery(message: messageContent)
        let stream: AsyncThrowingStream<ResponseStreamEvent, Error> = openAI.responses.createResponseStreaming(query: responseQuery)
        let response = ResponseStatus()
        return AsyncThrowingStream {
            continuation in
            Task {
                do {
                    for try await event in stream {
                        try response.handleResponseStreamEvent(event, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 发起对话，会进行多轮聊天直至收到 assistant 的回答
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> {
        var messageContent = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        messageContent = replaceOptions(content: messageContent, selectedText: ctx.text, options: options)
        return chatFollow(userMessage: UserMessage(text: messageContent))
    }

    private let maxToolLoops = 8

    /// 处理用户后续的消息
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error>  {
        updateQuery(message: userMessage)
        return AsyncThrowingStream { continuation in
            Task {
                var hasToolCall = false
                do {
                    for _ in 0..<maxToolLoops {
                        hasToolCall = try await chatOneRound(continuation: continuation)
                        if !hasToolCall {
                            continuation.yield(.done)
                            continuation.finish()
                            return
                        }
                    }
                    continuation.yield(.error("tooManyToolLoops"))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 单轮聊天流程，包括流式处理和工具调用
    private func chatOneRound(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> Bool  {
        do {
            let openAIStream: AsyncThrowingStream<ResponseStreamEvent, Error> =  openAI.responses.createResponseStreaming(query: responseQuery)

            let response = ResponseStatus()
            for try await event in openAIStream {
                do {
                    try response.handleResponseStreamEvent(event, continuation: continuation)
                } catch {
                    AppLogger.ai.debug("handleResponseStreamEvent \(error)")
                    throw error
                }
            }

            if response.hasToolsCalled {
                if let input = try await callTools(toolCallsDict: response.toolCallsDict, continuation: continuation) {
                    updateQueryWithToolOutput(lastResponseId: response.lastOpenAIResponseId!, input: input)
                    return true
                }
            } else {
                updateQuery(lastResponseId: response.lastOpenAIResponseId!)
            }
        }
        return false
    }

    // 内部方法：调用工具函数
    private func callTools(toolCallsDict: [String: FunctionCallParam], continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> CreateModelResponseQuery.Input? {
        guard let functions = tools else { return nil }

        // 构建工具映射
        var functionMap = [String: FunctionDefinition]()
        for function in functions {
            functionMap[function.name] = function
        }


        var input = [InputItem]()
        for (callId, tool) in toolCallsDict {
            // 如果工具定义中有模板，则渲染后更新消息
            var toolMessage = ""
            if let funcDef = functionMap[tool.name],
               let template = funcDef.template {
                toolMessage = renderTemplate(templateString: template, json: tool.arguments)
                AppLogger.ai.debug("\(toolMessage)")
            }
            continuation.yield(.toolCallStarted(.init(id: tool.id, name: tool.name, message: toolMessage)))

            // 根据工具名称调用不同的逻辑
            if tool.name == dalle3Def.name {
                let url = try await ImageGeneration.generateDalle3Image(openAI: openAI, arguments: tool.arguments)

                let item = Components.Schemas.Item.FunctionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: .case1(url)))
                input.append(.item(item))
                let ret = "[![this is picture](" + url + ")](" + url + ")"
                let message = ToolCallResult(id: tool.id, name: tool.name, ret: ret)
                continuation.yield(.toolCallFinished(message))
            } else if tool.name == svgToolOpenAIDef.name {
                _ = openSVGInBrowser(svgData: tool.arguments)

                let item = Components.Schemas.Item.FunctionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output:  .case1("display svg successfully")))
                input.append(.item(item))

                let message = ToolCallResult(id: tool.id, name: tool.name, ret: NSLocalizedString("display_svg", comment: ""))
                continuation.yield(.toolCallFinished(message))

            } else {
                if let funcDef = functionMap[tool.name] {
                    AppLogger.ai.debug("call: \(tool.arguments)")
                    if let ret = try funcDef.Run(arguments: tool.arguments, options: options) {
                        let statusMessage = (funcDef.showResult ?? true)
                        ? ret
                        : String(format: NSLocalizedString("called_tool", comment: "tool message"), funcDef.name)
                        let message = ToolCallResult(id: tool.id, name: tool.name, ret: statusMessage)
                        continuation.yield(.toolCallFinished(message))
                        let item = Components.Schemas.Item.FunctionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: .case1(ret)))
                        input.append(.item(item))
                    }
                }
            }
        }
        return CreateModelResponseQuery.Input.inputItemList(input)
    }

    private static func createResponseQuery(functions: [FunctionDefinition]?, model: OpenAIModel, thinking: Bool) -> CreateModelResponseQuery {
        var tools: [Tool]? = nil
        if let functions = functions {
            var toolList: [Tool] = [
                .functionTool(
                    .init(name: dalle3Def.name,
                          description: dalle3Def.description,
                          parameters: dalle3Def.parameters!, strict: false)),
                .functionTool(.init(name: svgToolOpenAIDef.name,
                                    description: svgToolOpenAIDef.description,
                                    parameters: svgToolOpenAIDef.parameters!, strict: false))
            ]
            for fc in functions {
                let fcConverted = Tool.functionTool(
                    .init(
                        name: fc.name,
                        description: fc.description,
                        parameters: fc.getParameters()!,
                        strict: false,
                    )
                )
                toolList.append(fcConverted)
            }
            tools = toolList
        }

        var reasoning: Components.Schemas.Reasoning? = nil
        if isReasoningModel(model) {
            var reasoningEffort = Defaults[.openAIModelReasoningEffort]
            if model == .gpt5_pro {
                reasoningEffort = .high
            }
            reasoning =  .init(
                effort: reasoningEffort,
                summary: .auto)

            if !(model == .gpt5 && reasoningEffort == .minimal) {
                if var toolList = tools {
                    toolList.append(.webSearchTool(.init(_type: .webSearch)))
                    tools = toolList
                }
            }
        }


        if !thinking && ( model == .gpt5_1 || model == .gpt5_2)  {
            // only support for gpt_5.1 which default reasoningEffort is none.
            reasoning = nil
        }

        return CreateModelResponseQuery(
            input: .textInput(""),
            model: model,
            instructions: systemPrompt(),
            reasoning:  reasoning,
            stream: true,
            text: .text,
            tools: tools,
        )
    }
}

fileprivate class ResponseStatus : ObservableObject {
    public var lastOpenAIResponseId: String?
    public var toolCallsDict: [String: FunctionCallParam]
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
                // Handle text annotations
                switch annotationEvent {
                    case .added(let event):
                        // TODO: Implement proper annotation handling when type conversion is resolved
                        AppLogger.ai.debug("Text annotation added: itemId=\(event.itemId), annotationIndex=\(event.annotationIndex)")
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
                        continuation.yield(.toolCallStarted(.init(id: webSearch.itemId, name: String(localized:  "Web search"), message: String(localized: "in progress"))))
                    case .searching(_):
                        break
                    case .completed(let webSearch):
                        continuation.yield(.toolCallFinished(.init(id: webSearch.itemId, name: String(localized:  "Web search"), ret: String(localized: "completed"))))
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

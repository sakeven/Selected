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
    static let gpt5_1 = "gpt-5.1"
}

let OpenAIModels: [Model] = [
    .gpt5_mini, .gpt5,
    .gpt4_1, .gpt4_1_mini, .o4_mini,
    .o3, .gpt4_o, .gpt4_o_mini, .o1, .o3_mini]
let OpenAITTSModels: [Model] = [.gpt_4o_mini_tts, .tts_1, .tts_1_hd]
let OpenAITranslationModels: [Model] = [.gpt4_1_mini, .gpt4_o, .gpt4_o_mini]

func isReasoningModel(_ model: Model) -> Bool {
    return [.gpt5_mini, .gpt5, .gpt5_1, .o4_mini, .o3, .o1, .o3_mini].contains(model)
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


typealias OpenAIChatCompletionMessageToolCallParam = ChatQuery.ChatCompletionMessageParam.AssistantMessageParam.ToolCallParam
typealias ChatFunctionCall = OpenAIChatCompletionMessageToolCallParam.FunctionCall
typealias FunctionParameters = ChatQuery.ChatCompletionToolParam.FunctionDefinition
typealias ChatCompletionMessageToolCallParam = OpenAIChatCompletionMessageToolCallParam


public class UserMessage {
    public var lastResponseId: String?
    public var message = ""

    init(message: String = "") {
        self.message = message
    }

    init(message: String = "", lastResponseId: String?) {
        self.message = message
        self.lastResponseId = lastResponseId
    }
}


final class MiddleWare: OpenAIMiddleware {
    func intercept(response: URLResponse?, request: URLRequest, data: Data?) -> (response: URLResponse?, data: Data?) {
                if let data = data {
                    print(String(data: data, encoding: .utf8) ?? "no data")
                } else {
                    print("no data2")
                }
        return (response, data)
    }
}

class OpenAIService: AIChatService{
    private let prompt: String
    private var tools: [FunctionDefinition]?
    private let openAI: OpenAI
    private var responseQuery: CreateModelResponseQuery
    private var options: [String: String]

    // 初始化时传入 prompt、工具列表和其他选项
    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:]) {
        self.prompt = prompt
        self.tools = tools
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey], host: host, timeoutInterval: 60.0, parsingOptions: .relaxed)
        self.openAI = OpenAI(configuration: configuration, middlewares: [MiddleWare()])
        self.options = options
        self.responseQuery = OpenAIService.createResponseQuery(functions: tools, model: Defaults[.openAIModel])
    }

    // 初始化时直接传入 prompt 和模型
    init(prompt: String, model: OpenAIModel) {
        self.prompt = prompt
        self.tools = nil
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey], host: host, timeoutInterval: 60.0)
        self.openAI = OpenAI(configuration: configuration)
        self.options = [:]
        self.responseQuery = OpenAIService.createResponseQuery(functions: tools, model: model)

    }

    // 更新对话查询
    private func updateQuery(message: UserMessage) {
        responseQuery = CreateModelResponseQuery(
            input: .textInput(message.message),
            model: responseQuery.model,
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
            previousResponseId: lastResponseId,
            reasoning: responseQuery.reasoning,
            stream: true,
            tools: responseQuery.tools,
        )
    }

    /// 单轮对话，适合简单返回结果（流式返回）
    func chatOne(selectedText: String, completion: @escaping (String) -> Void) async {
        let messageContent = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        updateQuery(message: .init(message: messageContent))

        do {

            let stream: AsyncThrowingStream<ResponseStreamEvent, Error> =  openAI.responses.createResponseStreaming(query: responseQuery)

            let response = ResponseStatus()
            for try await event in stream {
                try response.handleResponseStreamEvent(event, index: 0, completion: {_,_ in
                })
            }
        } catch {
            print("completion error \(error)")
        }
    }

    /// 发起对话，会进行多轮聊天直至收到 assistant 的回答
    func chat(ctx: ChatContext, completion: @escaping (Int, ResponseMessage) -> Void) async {
        var messageContent = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        messageContent = replaceOptions(content: messageContent, selectedText: ctx.text, options: options)
        await chatFollow(index: -1, userMessage: messageContent, completion: completion)
    }

    /// 处理用户后续的消息
    func chatFollow(index: Int, userMessage: String, completion: @escaping (Int, ResponseMessage) -> Void) async {
        updateQuery(message: .init(message: userMessage))

        var newIndex = index
        var hasToolCall = true
        while index < MAX_CHAT_ROUNDS && hasToolCall {
            do {
                hasToolCall = try await chatOneRound(index: &newIndex, completion: completion)
            } catch {
                newIndex += 1
                let localMsg = String(format: NSLocalizedString("error_exception", comment: "system info"), error as CVarArg)
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                completion(newIndex, message)
                return
            }
            if newIndex - index >= MAX_CHAT_ROUNDS {
                newIndex += 1
                let localMsg = NSLocalizedString("Too much rounds, please start a new chat", comment: "system info")
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                completion(newIndex, message)
                return
            }
        }
    }

    /// 单轮聊天流程，包括流式处理和工具调用
    private func chatOneRound(index: inout Int, completion: @escaping (Int, ResponseMessage) -> Void) async throws -> Bool {
        print("index is \(index)")

        completion(index + 1, ResponseMessage(message: NSLocalizedString("Waiting", comment: "system info"), role: .system, new: true, status: .initial))

        do {
            let stream: AsyncThrowingStream<ResponseStreamEvent, Error> =  openAI.responses.createResponseStreaming(query: responseQuery)

            let response = ResponseStatus()
            for try await event in stream {
                try response.handleResponseStreamEvent(event, index: index, completion: completion)
            }

            completion(index + 1, ResponseMessage(message: "", role: .assistant, new: false, status: .finished))
            print("response: \(response.inProgress)")
            if response.hasToolsCalled {
                if  let input = try await callTools(index: &index, toolCallsDict: response.toolCallsDict, completion: { idx, _ in
                }) {
                   updateQueryWithToolOutput(lastResponseId: response.lastOpenAIResponseId!, input: input)
                return true
               }
            } else {
                updateQuery(lastResponseId: response.lastOpenAIResponseId!)
            }
        } catch {
            print("completion error \(error)")
        }
        return false
    }

    // 内部方法：调用工具函数
    private func callTools(index: inout Int, toolCallsDict: [String: FunctionCallParam], completion: @escaping (Int, ResponseMessage) -> Void) async throws -> CreateModelResponseQuery.Input? {
        guard let functions = tools else { return nil }

        index += 1
        print("tool index \(index)")

        // 构建工具映射
        var functionMap = [String: FunctionDefinition]()
        for function in functions {
            functionMap[function.name] = function
        }


        var input = [InputItem]()
        for (callId, tool) in toolCallsDict {
            let toolMessage = ResponseMessage(
                message: String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name),
                role: .assistant,
                new: true,
                status: .updating
            )
            // 如果工具定义中有模板，则渲染后更新消息
            if let funcDef = functionMap[tool.name],
               let template = funcDef.template {
                toolMessage.message = renderTemplate(templateString: template, json: tool.arguments)
                print("\(toolMessage.message)")
            }
            completion(index, toolMessage)
            print("\(tool.arguments)")

            // 根据工具名称调用不同的逻辑
            if tool.name == dalle3Def.name {
                let url = try await ImageGeneration.generateDalle3Image(openAI: openAI, arguments: tool.arguments)

                let item = Components.Schemas.Item.functionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: url))
                input.append(.item(item))
                let ret = "[![this is picture](" + url + ")](" + url + ")"
                let message = ResponseMessage(message: ret, role: .assistant, new: true, status: .finished)
                completion(index, message)
            } else if tool.name == svgToolOpenAIDef.name {
                _ = openSVGInBrowser(svgData: tool.arguments)

                let item = Components.Schemas.Item.functionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: ("display svg successfully")))
                input.append(.item(item))

                let message = ResponseMessage(message: NSLocalizedString("display_svg", comment: ""), role: .assistant, new: true, status: .finished)
                completion(index, message)
            } else {
                if let funcDef = functionMap[tool.name] {
                    print("call: \(tool.arguments)")
                    if let ret = try funcDef.Run(arguments: tool.arguments, options: options) {
                        let statusMessage = (funcDef.showResult ?? true)
                        ? ret
                        : String(format: NSLocalizedString("called_tool", comment: "tool message"), funcDef.name)
                        let message = ResponseMessage(message: statusMessage, role: .assistant, new: true, status: .finished)
                        completion(index, message)

                        let item = Components.Schemas.Item.functionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: ret))
                        input.append(.item(item))
                    }
                }
            }
        }
        return CreateModelResponseQuery.Input.inputItemList(input)
    }

    private static func createResponseQuery(functions: [FunctionDefinition]?, model: OpenAIModel) -> CreateModelResponseQuery {

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

        typealias ReasoningEffort = Components.Schemas.ReasoningEffort
        var reasoning: Components.Schemas.Reasoning? = nil
        if isReasoningModel(model){
            let reasoningEffort: ReasoningEffort = switch Defaults[.openAIModelReasoningEffort]{
                case "low": .low
                case "medium": .medium
                case "high": .high
                default: .medium
            }
            reasoning =  .init(
                effort: reasoningEffort,
                summary: .auto)
        }

        return CreateModelResponseQuery(
            input: .textInput(""),
            model: model,
            instructions: systemPrompt(),
            reasoning:  reasoning,
            stream: true,
            tools: tools,
        )
    }
}

public class ResponseStatus : ObservableObject {
    @Published private(set) var inProgress = false

    private var responseBeingStreamed: ResponseData?
    public var lastOpenAIResponseId: String?

    public var toolCallsDict: [String: FunctionCallParam]

    public var hasToolsCalled: Bool {
        get {
            !toolCallsDict.isEmpty
        }
    }

    private class MessageData {
        let id: String

        var text: String = ""
        var refusalText: String = ""
        var annotations: [ResponseStreamEvent.Annotation] = []

        init(id: String, text: String, annotations: [ResponseStreamEvent.Annotation]) {
            self.id = id
            self.text = text
            self.annotations = annotations
        }
    }

    private class ResponseData {
        let id: String
        var message: MessageData?

        init(id: String, message: MessageData? = nil) {
            self.id = id
            self.message = message
        }
    }


    private var messageBeingStreamed: MessageData? {
        get {
            responseBeingStreamed?.message
        }

        set {
            assert(responseBeingStreamed != nil)
            responseBeingStreamed?.message = newValue
        }
    }

    public init() {
        self.inProgress = true
        self.toolCallsDict = [String: FunctionCallParam]()
    }

    public func handleResponseStreamEvent(_ event: ResponseStreamEvent, index: Int, completion: @escaping (Int, ResponseMessage) -> Void) throws {
        switch event {
            case .created(let responseEvent):
                // #1
                inProgress = true
                completion(index + 1, ResponseMessage(message: "", role: .assistant, new: true, status: .updating))
                responseBeingStreamed = .init(id: responseEvent.response.id)
                // Track the actual OpenAI response ID for API continuity
                lastOpenAIResponseId = responseEvent.response.id
            case .inProgress(_ /* let responseInProgressEvent */):
                // #2
                inProgress = true
            case .outputItem(let outputItemEvent):
                try handleOutputItemEvent(outputItemEvent)
            case .functionCallArguments(_):
                break
            case .contentPart(.added(let contentPartAddedEvent)):
                try updateMessageBeingStreamed(
                    messageId: contentPartAddedEvent.itemId,
                    outputContent: contentPartAddedEvent.part
                )
            case .outputText(let outputTextEvent):
                try handleOutputTextEvent(outputTextEvent)
            case .contentPart(.done(let contentPartDoneEvent)):
                try updateMessageBeingStreamed(
                    messageId: contentPartDoneEvent.itemId,
                    outputContent: contentPartDoneEvent.part,
                )
            case .completed(_ /* let responseEvent */):
                // # 29
                responseBeingStreamed = nil
                inProgress = false
            case .queued(_ /* let responseEvent */):
                // Response is queued - no action needed
                break
            case .failed(_ /* let responseEvent */):
                // Response failed - could show error in UI
                print("Response failed")
                break
            case .incomplete(_ /* let responseEvent */):
                // Response incomplete - could show warning in UI
                print("Response incomplete")
                break
            case .error(let errorEvent):
                // Error event - log the error
                print("Response error: \(errorEvent)")
                break
            case .refusal(let refusalEvent):
                // Refusal event - handle refusal
                print("Response refusal: \(refusalEvent)")
                break
            case .outputTextAnnotation(let annotationEvent):
                // Handle text annotations
                switch annotationEvent {
                    case .added(let event):
                        // TODO: Implement proper annotation handling when type conversion is resolved
                        print("Text annotation added: itemId=\(event.itemId), annotationIndex=\(event.annotationIndex)")
                }
            case .reasoning(let reasoningEvent):
                // Handle reasoning events - could show reasoning in UI
                switch reasoningEvent {
                    case .delta(let event):
                        print("Reasoning delta: \(event.sequenceNumber)")
                    case .done(let event):
                        print("Reasoning done: \(event.sequenceNumber)")
                }
            case .reasoningSummary(let reasoningSummaryEvent):
                // Handle reasoning summary events
                switch reasoningSummaryEvent {
                    case .delta(let event):
                        print("Reasoning summary delta: \(event.sequenceNumber)")
                    case .done(let event):
                        print("Reasoning summary done: \(event.sequenceNumber)")
                }
            case .audio(_ /* let audioEvent */):
                // Audio events - not implemented yet
                print("Audio event received (not implemented)")
                break
            case .audioTranscript(_ /* let audioTranscriptEvent */):
                // Audio transcript events - not implemented yet
                print("Audio transcript event received (not implemented)")
                break
            case .codeInterpreterCall(_ /* let codeInterpreterCallEvent */):
                // Code interpreter events - not implemented yet
                print("Code interpreter call event received (not implemented)")
                break
            case .fileSearchCall(_ /* let fileSearchCallEvent */):
                // File search events - not implemented yet
                print("File search call event received (not implemented)")
                break
            case .imageGenerationCall(_ /* let imageGenerationCallEvent */):
                // Image generation events - not implemented yet
                print("Image generation call event received (not implemented)")
                break
            case .reasoningSummaryPart(_ /* let reasoningSummaryPartEvent */):
                // Reasoning summary part events - not implemented yet
                print("Reasoning summary part event received (not implemented)")
                break
            case .reasoningSummaryText(_ /* let reasoningSummaryTextEvent */):
                // Reasoning summary text events - not implemented yet
                print("Reasoning summary text event received (not implemented)")
                break
            case .webSearchCall(_):
                break
            case .mcpCall(_):
                break
            case .mcpCallArguments(_):
                break
            case .mcpListTools(_):
                break
        }

        if let response = responseBeingStreamed {
            if let messgage = response.message {
                completion(index + 1, ResponseMessage(message: messgage.text, role: .assistant, new: true, status: .updating))
            }
        }
    }

    private func handleOutputItemEvent(_ event: ResponseStreamEvent.OutputItemEvent) throws {
        switch event {
            case .added(let outputItemAddedEvent):
                try handleOutputItemAdded(outputItemAddedEvent.item)
            case .done(let outputItemDoneEvent):
                try handleOutputItemDone(outputItemDoneEvent.item)
        }
    }

    private func handleOutputItemAdded(_ outputItem: OutputItem) throws {
        switch outputItem {
            case .outputMessage(let outputMessage):
                // Message, role: assistant
                // let role = outputMessage.role.rawValue
                // outputMessage.content is empty, but we can add empty message just to show a progress
                try setMessageBeingStreamed(message: .init(
                    id: outputMessage.id,
                    text: "",
                    annotations: []
                ))
            case .webSearchToolCall(_ /* let webSearchToolCall */):
                break
            case .functionToolCall(_):
                break
            case .mcpApprovalRequest(_ /*let approvalRequest*/):
                break
            case .mcpListTools(_ /* let mcpListTools */):
                // MCP tools listed - no UI action needed
                break
            case .mcpToolCall(_ /* let mcpCall */):
                // MCP tool call in progress - no UI action needed
                break
            default:
                break
        }
    }

    private func handleOutputItemDone(_ outputItem: OutputItem) throws {
        switch outputItem {
            case .outputMessage(let outputMessage):
                // Message. Role: assistant
                assert(outputMessage.id == messageBeingStreamed?.id)
                for content in outputMessage.content {
                    try updateMessageBeingStreamed(
                        messageId: outputMessage.id,
                        outputContent: content
                    )
                }
                messageBeingStreamed = nil
            case .webSearchToolCall(_ /* let webSearchToolCall */):
                break
            case .functionToolCall(let functionToolCall):
                toolCallsDict[functionToolCall.callId] = FunctionCallParam(name: functionToolCall.name, arguments: functionToolCall.arguments)
                break
            case .mcpApprovalRequest(_ /* let approvalRequest */):
                // MCP approval request completed - no additional action needed
                break
            case .mcpListTools(_ /* let mcpListTools */):
                // MCP tools listing completed - no additional action needed
                break
            case .mcpToolCall(_):
                break
            default:
                break
        }
    }

    private func updateMessageBeingStreamed(
        messageId: String,
        outputContent: ResponseStreamEvent.Schemas.OutputContent
    ) throws {
        try updateMessageBeingStreamed(messageId: messageId) { message in
            switch outputContent {
                case .OutputTextContent(let outputText):
                    message.text = outputText.text
                    message.annotations = outputText.annotations
                case .RefusalContent(let refusal):
                    message.refusalText = refusal.refusal
            }
        }
    }


    private func updateMessageBeingStreamed(messageId: String, _ updateClosure: (MessageData) -> Void) throws {
        guard let responseBeingStreamed else {
            return
        }

        guard let messageBeingStreamed else {
            return
        }

        guard messageBeingStreamed.id == messageId else {
            return
        }

        updateClosure(messageBeingStreamed)
    }

    private func handleOutputTextEvent(_ outputTextEvent: ResponseStreamEvent.OutputTextEvent) throws {
        switch outputTextEvent {
            case .delta(let responseTextDeltaEvent):
                try applyOutputTextDeltaToMessageBeingStreamed(
                    messageId: responseTextDeltaEvent.itemId,
                    newText: responseTextDeltaEvent.delta
                )
                // Note: Annotations are now handled via separate outputTextAnnotation events
            case .done(let responseTextDoneEvent):
                if messageBeingStreamed?.text != responseTextDoneEvent.text {
                    return
                }
        }
    }

    private func applyOutputTextDeltaToMessageBeingStreamed(messageId: String, newText: String) throws {
        try updateMessageBeingStreamed(messageId: messageId) { message in
            message.text += newText
        }
    }

    private func setMessageBeingStreamed(message: MessageData) throws {
        guard let responseBeingStreamed else {
            fatalError()
        }

        messageBeingStreamed = message
    }
}

public struct FunctionCallParam {
    public var name: String
    public var arguments: String
}

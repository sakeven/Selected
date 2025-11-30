////
////  Claude.swift
////  Selected
////
////  Created by sake on 2024/7/13.
////
//
//import Foundation
//import SwiftAnthropic
//import Defaults
//
//// MARK: - 工具使用数据模型
//
//fileprivate struct ToolUse {
//    let id: String
//    let name: String
//    var input: String
//}
//
//// MARK: - 工具管理模块
//
//fileprivate struct ToolsManager {
//
//    /// 根据 FunctionDefinition 列表生成工具描述
//    static func generateTools(from functions: [FunctionDefinition]?) -> [MessageParameter.Tool] {
//        guard let functions = functions else { return [] }
//        var tools = [MessageParameter.Tool]()
//        for fc in functions {
//            let schema = try! JSONDecoder().decode(JSONSchema.self, from: fc.parameters.data(using: .utf8)!)
//            let tool = MessageParameter.Tool.function(name: fc.name, description: fc.description, inputSchema: schema)
//            tools.append(tool)
//        }
//        return tools
//    }
//
//    /// 根据工具使用列表调用相应的工具函数，并返回工具调用结果消息
//    static func callTools(
//        index: inout Int,
//        toolUseList: [ToolUse],
//        with functionDefinitions: [FunctionDefinition],
//        options: [String: String],
//        completion: @escaping (_: Int, _: ResponseMessage) -> Void
//    ) async throws -> [MessageParameter.Message] {
//        index += 1
//        var fcSet = [String: FunctionDefinition]()
//        for fc in functionDefinitions {
//            fcSet[fc.name] = fc
//        }
//        var toolUseResults = [MessageParameter.Message.Content.ContentObject]()
//
//        for tool in toolUseList {
//            if tool.name == "display_svg" {
//                let rawMessage = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
//                var message = ResponseMessage(message: rawMessage, role: .assistant, new: true, status: .updating)
//                completion(index, message)
//                // 打开 SVG 浏览器预览
//                _ = openSVGInBrowser(svgData: tool.input)
//                message = ResponseMessage(message: String(format: NSLocalizedString("display_svg", comment: "")), role: .assistant, new: true, status: .finished)
//                completion(index, message)
//                toolUseResults.append(.toolResult(tool.id, "display svg successfully"))
//                continue
//            }
//
//            guard let fc = fcSet[tool.name] else { continue }
//            let rawMessage = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
//            let message = ResponseMessage(message: rawMessage, role: .assistant, new: true, status: .updating)
//            if let template = fc.template {
//                message.message = renderTemplate(templateString: template, json: tool.input)
//            }
//            completion(index, message)
//
//            if let ret = try fc.Run(arguments: tool.input, options: options) {
//                let resultMessage = ResponseMessage(message: ret, role: .assistant, new: true, status: .finished)
//                if let show = fc.showResult, !show {
//                    resultMessage.message = fc.template != nil ? "" : String(format: NSLocalizedString("called_tool", comment: "tool message"), fc.name)
//                }
//                completion(index, resultMessage)
//                toolUseResults.append(.toolResult(tool.id, ret))
//            }
//        }
//        return [.init(role: .user, content: .list(toolUseResults))]
//    }
//}
//// MARK: - 聊天服务模块
//
//class ClaudeProvider: AIProvider {
//    private let service: AnthropicService
//    private let prompt: String
//    private let options: [String: String]
//    private var queryManager: QueryManager
//    private let tools: [FunctionDefinition]?
//
//    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:]) {
//        var apiHost = "https://api.anthropic.com"
//        if Defaults[.claudeAPIHost] != "" {
//            apiHost = Defaults[.claudeAPIHost]
//        }
//        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey], basePath: apiHost, betaHeaders: nil)
//        self.prompt = prompt
//        self.options = options
//
//        // 生成工具描述并添加 SVG 工具
//        var toolsParam = ToolsManager.generateTools(from: tools)
//        toolsParam.append(svgToolClaudeDef)
//        self.tools = tools
//        self.queryManager = QueryManager(model: .other(Defaults[.claudeModel]), systemPrompt: systemPrompt(), tools: toolsParam)
//    }
//
//    /// 单次聊天：仅发送一条消息，返回流式响应内容
//    func chatOnce(selectedText: String) async -> AsyncThrowingStream<AIStreamEvent, Error> {
//        let userMessage = replaceOptions(content: prompt, selectedText: selectedText, options: options)
//        let parameters = MessageParameter(
//            model: .claude35Sonnet,
//            messages: [.init(role: .user, content: .text(userMessage))],
//            maxTokens: 4096
//        )
//
//        return AsyncThrowingStream {
//            continuation in
//            Task {
//                let stream = try await service.streamMessage(parameters)
//                let response = ResponseStatus2()
//                for try await event in stream {
//                    try response.handleResponseStreamEvent(event, continuation: continuation)
//                }
//            }
//        }
//    }
//
//    let maxToolLoops = 8
//
//    /// 聊天跟进：追加用户消息，并循环处理直到得到完整回复
//    func chatFollow(userMessage: String,  lastResponseId: String?) -> AsyncThrowingStream<AIStreamEvent, Error>{
//        queryManager.update(with: .init(role: .user, content: .text(userMessage)))
//        var newIndex = index
//        return AsyncThrowingStream { continuation in
//            Task {
//                var hasToolCall = false
//                for _ in 0..<maxToolLoops {
//                    hasToolCall = await chatOneRound(continuation: continuation)
//                    if !hasToolCall {
//                        continuation.yield(.done)
//                        continuation.finish()
//                        return
//                    }
//                }
//                continuation.yield(.error("tooManyToolLoops"))
//                continuation.finish()
//            }
//        }
//    }
//
//    /// 根据聊天上下文进行整体对话
//    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error>{
//        var userMessage = renderChatContent(content: prompt, chatCtx: ctx, options: options)
//        userMessage = replaceOptions(content: userMessage, selectedText: ctx.text, options: options)
//        return chatFollow(userMessage: userMessage, lastResponseId: nil)
//    }
//
//    /// 单轮聊天处理：流式接收回复，并处理可能的工具调用
//    private func chatOneRound(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async -> Bool  {
//        do {
//            let stream = try await service.streamMessage(queryManager.query)
//            let response = ResponseStatus2()
//            for try await event in stream {
//                try response.handleResponseStreamEvent(event, continuation: continuation)
//            }
//
////            if response.hasToolsCalled {
////                // 将工具调用封装到查询记录中
////                for (_, tool) in response.toolCallsDict {
////                    let input = try JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self, from: tool.input.data(using: .utf8)!)
////                    contents.append(.toolUse(tool.id, tool.name, input))
////                }
////            }
//
//            // 调用工具，并将工具结果追加到查询记录
//            if let functions = tools, response.hasToolsCalled {
//                let toolMessages = try await ToolsManager.callTools(toolUseList: toolCallsDict, with: functions, options: options)
//                if !toolMessages.isEmpty {
//                    queryManager.update(with: toolMessages)
//                }
//            }
//        } catch {
//
//        }
//    }
//}
//
//
//fileprivate class ResponseStatus2 : ObservableObject {
//    public var toolCallsDict: [String: FunctionCallParam]
//    public var hasToolsCalled: Bool {
//        get {
//            !toolCallsDict.isEmpty
//        }
//    }
//
//    public init() {
//        self.toolCallsDict = [String: FunctionCallParam]()
//    }
//
//    func handleResponseStreamEvent(_ event: MessageStreamResponse, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation ) throws {
//        guard let eventType = MessageStreamResponse.StreamEvent(rawValue: event.type) else { return }
//
//        switch eventType {
//            case .contentBlockStart:
//                if let block = event.contentBlock, block.type == "tool_use", let tool = block.toolUse {
//                    let call = FunctionCallParam(name: tool.name, arguments: "")
//                    toolCallsDict[tool.id] = call
//                }
//
//            case .contentBlockDelta:
//                if let delta = event.delta {
//                    // 文本增量
//                    if let text = delta.text, !text.isEmpty {
//                        // reasoning：Claude 3.7 thinking 模式目前是一个单独的 content block type= "thinking"
//                        // 实际识别方式要看官方文档，这里简单示意：
//                        let isReasoning = (delta.type == "thinking")
//                        if isReasoning {
//                            continuation.yield(.reasoningDelta(text))
//                        } else {
//                            continuation.yield(.textDelta(text))
//                        }
//                    }
//
//                    // 工具参数 partialJson
//                    if let partial = delta.partialJson, !partial.isEmpty {
//                        // 这里 Anthropic 用 index 区分 block，简化处理：假设当前 index 对应唯一一个 tool_use
//                        if let idx = event.index {
//                            // 实际上你可以维护 index -> toolId 映射
//                            let toolId = "tool-\(idx)"
//                            if toolCallsDict[toolId] == nil {
//                                toolCallsDict[toolId] = .init(name: "unknown", arguments: "")
//                            }
//                            toolCallsDict[toolId]?.arguments += partial
//                        }
//                    }
//                }
//
//            case .contentBlockStop:
//                if let block = event.contentBlock, block.type == "tool_use", let tool = block.toolUse {
//                    if var call = toolCallsDict[tool.id] {
//                        // argumentsJSON 已经在 partialJson 阶段累积完了
//                        call.name = tool.name
//                        toolCallsDict[tool.id] = call
//                    }
//                }
//
//            case .messageDelta:
//                if let delta = event.delta {
//                    if let stopReason = delta.stopReason, stopReason != "" {
//                        return
//                    }
//                }
//
//            case .messageStart, .messageStop:
//                // 这些事件你按需处理，这里忽略
//                break
//        }
//    }
//}

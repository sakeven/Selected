//
//  Claude.swift
//  Selected
//
//  Created by sake on 2024/7/13.
//

import Foundation
import SwiftAnthropic
import Defaults

// MARK: - 模型与扩展

//public typealias ClaudeModel = Model

extension ClaudeModel: @retroactive CaseIterable {
    public static var allCases: [ClaudeModel] {
        [.claude_sonnet_4_5, .claude_haiku_4_5, .claude_opus_4_5, .claude_opus_4_1]
    }
}

public typealias ClaudeModel = String

public extension ClaudeModel {
    static let claude_sonnet_4_5 = "claude-sonnet-4-5"
    static let claude_haiku_4_5 = "claude-haiku-4-5"
    static let claude_opus_4_5 = "claude-opus-4-5"
    static let claude_opus_4_1 = "claude-opus-4-1"
}




// MARK: - 工具使用数据模型

fileprivate struct ToolUse {
    let id: String
    let name: String
    var input: String
}

// MARK: - 工具管理模块

fileprivate struct ToolsManager {

    /// 根据 FunctionDefinition 列表生成工具描述
    static func generateTools(from functions: [FunctionDefinition]?) -> [MessageParameter.Tool] {
        guard let functions = functions else { return [] }
        var tools = [MessageParameter.Tool]()
        for fc in functions {
            let schema = try! JSONDecoder().decode(JSONSchema.self, from: fc.parameters.data(using: .utf8)!)
            let tool = MessageParameter.Tool.function(name: fc.name, description: fc.description, inputSchema: schema)
            tools.append(tool)
        }
        return tools
    }

    /// 根据工具使用列表调用相应的工具函数，并返回工具调用结果消息
    static func callTools(
        toolUseList: [ToolUse],
        with functionDefinitions: [FunctionDefinition],
        options: [String: String],
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation,
    ) async throws -> [MessageParameter.Message] {
        var fcSet = [String: FunctionDefinition]()
        for fc in functionDefinitions {
            fcSet[fc.name] = fc
        }
        var toolUseResults = [MessageParameter.Message.Content.ContentObject]()

        for tool in toolUseList {

            if tool.name == "display_svg" {
                continuation.yield(.toolCallStarted(.init(id: tool.id, name: tool.name, message: NSLocalizedString("calling_tool", comment: "tool message"))))
                // 打开 SVG 浏览器预览
                _ = openSVGInBrowser(svgData: tool.input)
                let msg = String(format: NSLocalizedString("display_svg", comment: ""))
                continuation.yield(.toolCallFinished(.init(id: tool.id, name: tool.name, ret: msg)))
                toolUseResults.append(.toolResult(tool.id, "display svg successfully"))
                continue
            }

            guard let fc = fcSet[tool.name] else { continue }

            var message = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
            if let template = fc.template {
                message = renderTemplate(templateString: template, json: tool.input)
            }
            continuation.yield(.toolCallStarted(.init(id: tool.id, name: tool.name, message: message)))

            if let ret = try fc.Run(arguments: tool.input, options: options) {
                continuation.yield(.toolCallFinished(.init(id: tool.id, name: tool.name, ret: ret)))
                toolUseResults.append(.toolResult(tool.id, ret))
            }
        }
        return [.init(role: .user, content: .list(toolUseResults))]
    }
}

// MARK: - 查询管理模块

fileprivate struct QueryManager {
    private(set) var query: MessageParameter
    private let _tools: [MessageParameter.Tool]

    init(model: Model, systemPrompt: String, tools: [MessageParameter.Tool], reasoning: Bool) {
        var thinking: MessageParameter.Thinking? = nil
        if reasoning {
            thinking = .init(budgetTokens: 2048)
        }
        self.query = MessageParameter(
            model: .other(model.value),
            messages: [],
            maxTokens: 4096,
            system: MessageParameter.System.text(systemPrompt),
            tools: tools,
            thinking: thinking
        )
        self._tools = tools
    }

    mutating func update(with message: MessageParameter.Message) {
        var messages = query.messages
        messages.append(message)
        query = MessageParameter(
            model: .other(query.model),
            messages: messages,
            maxTokens: 4096,
            system: query.system,
            tools: self._tools,
            thinking: query.thinking
        )
    }

    mutating func update(with messages: [MessageParameter.Message]) {
        var _messages = query.messages
        _messages.append(contentsOf: messages)
        query = MessageParameter(
            model: .other(query.model),
            messages: _messages,
            maxTokens: 4096,
            system: query.system,
            tools: self._tools,
            thinking: query.thinking
        )
    }
}

// MARK: - 聊天服务模块

class ClaudeAIProvider: AIProvider {
    private let service: AnthropicService
    private let prompt: String
    private let options: [String: String]
    private var queryManager: QueryManager
    private let tools: [FunctionDefinition]?

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:], reasoning: Bool = true) {
        var apiHost = "https://api.anthropic.com"
        if Defaults[.claudeAPIHost] != "" {
            apiHost = Defaults[.claudeAPIHost]
        }
        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey], basePath: apiHost, betaHeaders: nil)
        self.prompt = prompt
        self.options = options

        // 生成工具描述并添加 SVG 工具
        var toolsParam = ToolsManager.generateTools(from: tools)
        toolsParam.append(svgToolClaudeDef)
        self.tools = tools
        self.queryManager = QueryManager(model: .other(Defaults[.claudeModel]), systemPrompt: systemPrompt(), tools: toolsParam, reasoning: reasoning)
    }


    // init claude service without tools and thinking
    init(prompt: String, model: ClaudeModel) {
        var apiHost = "https://api.anthropic.com"
        if Defaults[.claudeAPIHost] != "" {
            apiHost = Defaults[.claudeAPIHost]
        }
        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey], basePath: apiHost, betaHeaders: nil)
        self.prompt = prompt
        self.options = [String: String]()
        self.tools = []
        self.queryManager = QueryManager(model: .other(model), systemPrompt: systemPrompt(), tools: [], reasoning: false)
    }

    /// 单次聊天：仅发送一条消息，返回流式响应内容
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let userMessage = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        let parameters = MessageParameter(
            model: .other(queryManager.query.model),
            messages: [.init(role: .user, content: .text(userMessage))],
            maxTokens: 4096
        )

        return AsyncThrowingStream {
            continuation in
            Task {
                do {
                    let stream = try await service.streamMessage(parameters)
                    var fullText = ""
                    for try await result in stream {
                        let content = result.delta?.text ?? ""
                        if !content.isEmpty {
                            fullText += content
                            continuation.yield(.textDelta(content))
                        }
                    }
                    continuation.yield(.textDone(fullText))
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    AppLogger.ai.error("claude error \(error)")
                    continuation.finish(throwing:  error)
                }
            }
        }

    }

    let maxToolLoops = 8

    /// 根据聊天上下文进行整体对话
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> {
        var userMessage = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        userMessage = replaceOptions(content: userMessage, selectedText: ctx.text, options: options)
        queryManager.update(with: .init(role: .user, content: .text(userMessage)))
        return chatFollow(userMessage: UserMessage(text: userMessage))
    }

    /// 聊天跟进：追加用户消息，并循环处理直到得到完整回复
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error>  {
        if userMessage.images.isEmpty {
            queryManager.update(with: .init(role: .user, content: .text(userMessage.text)))
        } else {
            var content = [MessageParameter.Message.Content.ContentObject]()
            for image in userMessage.images {
                content.append(.image(.init(type: .base64, mediaType: .jpeg, data: image.base64EncodedString())))
            }
            content.append(.text( userMessage.text))
            queryManager.update(with: .init(role: .user, content: .list(content)))
        }

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

    /// 单轮聊天处理：流式接收回复，并处理可能的工具调用
    private func chatOneRound(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> Bool  {
        var assistantMessage = ""
        var thinking = ""
        var toolParameters = ""
        var signature = ""
        var toolUseList = [ToolUse]()
        var lastToolUseBlockIndex = -1

        continuation.yield(.begin(""))


            let stream = try await service.streamMessage(queryManager.query)
            for try await result in stream {
                let content = result.delta?.text ?? ""
                if !content.isEmpty {
                    continuation.yield(.textDelta(content))
                    assistantMessage += content
                }

                let deltaThinking = result.delta?.thinking ?? ""
                if !deltaThinking.isEmpty {
                    thinking += deltaThinking
                    continuation.yield(.reasoningDelta(deltaThinking))
                }
                signature += result.delta?.signature ?? ""

                switch result.streamEvent {
                    case .contentBlockStart:
                        if let toolUse = result.contentBlock?.toolUse {
                            toolUseList.append(ToolUse(id: toolUse.id, name: toolUse.name, input: ""))
                            toolParameters = ""
                            lastToolUseBlockIndex = result.index!
                        }
                    case .contentBlockDelta:
                        if lastToolUseBlockIndex == result.index! {
                            toolParameters += result.delta?.partialJson ?? ""
                        }
                    case .contentBlockStop:
                        if lastToolUseBlockIndex == result.index! {
                            var toolUse = toolUseList.last!
                            toolUse.input = jsonify(toolParameters)
                            toolUseList[toolUseList.count - 1] = toolUse
                        }
                    default:
                        break
                }
            }

            continuation.yield(.reasoningDone(thinking))

            if !assistantMessage.isEmpty {
                continuation.yield(.textDone(assistantMessage))
            }

            var contents = [MessageParameter.Message.Content.ContentObject]()
            if !thinking.isEmpty {
                contents.append(.thinking(thinking, signature))
            }
            contents.append(.text(assistantMessage))


            // 将工具调用封装到查询记录中
            for tool in toolUseList {
                let input = try JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self, from: tool.input.data(using: .utf8)!)
                contents.append(.toolUse(tool.id, tool.name, input))
            }
            queryManager.update(with: .init(role: .assistant, content: .list(contents)))

            // 调用工具，并将工具结果追加到查询记录
            if let functions = tools, !toolUseList.isEmpty {
                let toolMessages = try await ToolsManager.callTools(toolUseList: toolUseList, with: functions, options: options, continuation: continuation)
                if !toolMessages.isEmpty {
                    queryManager.update(with: toolMessages)
                }
            }
            return !toolUseList.isEmpty
    }
}

let ClaudeWordTrans =
ClaudeAIProvider(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let ClaudeTrans2Chinese = ClaudeAIProvider(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}")

let ClaudeTrans2English = ClaudeAIProvider(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")


let svgToolClaudeDef = MessageParameter.Tool.function(
    name: "display_svg",
    description: "When user requests you to create an SVG, you can use this tool to display the SVG.",
    inputSchema: .init(type: .object, properties:[
        "raw": .init(type: .string, description: "SVG content")
    ])
)

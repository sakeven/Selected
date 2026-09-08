import Foundation
import SwiftAnthropic
import Defaults

class ClaudeAIProvider: AIProvider {
    private let service: AnthropicService
    private let prompt: String
    private let options: [String: String]
    private var queryManager: ClaudeQuery
    private let tools: [FunctionDefinition]?

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:], reasoning: Bool = true) {
        var apiHost = "https://api.anthropic.com"
        if Defaults[.claudeAPIHost] != "" {
            apiHost = Defaults[.claudeAPIHost]
        }
        service = AnthropicServiceFactory.service(apiKey: APIKeyStore.shared.value(for: .claude), basePath: apiHost, betaHeaders: nil)
        self.prompt = prompt
        self.options = options

        // 生成工具描述并添加 SVG 工具
        var toolsParam = ClaudeTools.generateTools(from: tools)
        toolsParam.append(svgToolClaudeDef)
        self.tools = tools
        self.queryManager = ClaudeQuery(model: .other(Defaults[.claudeModel]), systemPrompt: systemPrompt(), tools: toolsParam, reasoning: reasoning)
    }


    // init claude service without tools and thinking
    init(prompt: String, model: ClaudeModel) {
        var apiHost = "https://api.anthropic.com"
        if Defaults[.claudeAPIHost] != "" {
            apiHost = Defaults[.claudeAPIHost]
        }
        service = AnthropicServiceFactory.service(apiKey: APIKeyStore.shared.value(for: .claude), basePath: apiHost, betaHeaders: nil)
        self.prompt = prompt
        self.options = [String: String]()
        self.tools = []
        self.queryManager = ClaudeQuery(model: .other(model), systemPrompt: systemPrompt(), tools: [], reasoning: false)
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
        chatFollow(userMessage: ctx.message(prompt: prompt, options: options))
    }

    /// 聊天跟进：追加用户消息，并循环处理直到得到完整回复
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error>  {
        do {
            queryManager.update(with: .init(role: .user, content: try Self.messageContent(userMessage)))
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return conversationStream(maxToolLoops: maxToolLoops) { continuation in
            try await self.chatOneRound(continuation: continuation)
        }
    }

    static func messageContent(_ message: UserMessage) throws -> MessageParameter.Message.Content {
        if message.images.isEmpty && message.files.isEmpty {
            return .text(message.text)
        }
        var content = [MessageParameter.Message.Content.ContentObject]()
        for file in message.files {
            if file.mimeType == "text/plain" {
                content.append(.text(String(decoding: file.data, as: UTF8.self)))
            } else {
                content.append(.document(try .pdf(base64Data: file.data.base64EncodedString(), title: file.filename)))
            }
        }
        for image in message.images {
            let isPNG = image.starts(with: [0x89, 0x50, 0x4E, 0x47])
            content.append(.image(.init(type: .base64, mediaType: isPNG ? .png : .jpeg, data: image.base64EncodedString())))
        }
        content.append(.text(message.text))
        return .list(content)
    }

    /// 单轮聊天处理：流式接收回复，并处理可能的工具调用
    private func chatOneRound(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> Bool  {
        var response = ClaudeResponseState()
        continuation.yield(.begin(""))
        let stream = try await service.streamMessage(queryManager.query)
        for try await result in stream {
            try response.consume(result, continuation: continuation)
        }
        queryManager.update(with: try response.finish(continuation: continuation))
        let toolUseList = response.toolUseList

        // 调用工具，并将工具结果追加到查询记录
        if let functions = tools, !toolUseList.isEmpty {
            let toolMessages = try await ClaudeTools.callTools(toolUseList: toolUseList, with: functions, options: options, continuation: continuation)
            if !toolMessages.isEmpty {
                queryManager.update(with: toolMessages)
            }
        }
        return !toolUseList.isEmpty
    }
}

let svgToolClaudeDef = MessageParameter.Tool.function(
    name: "display_svg",
    description: "When user requests you to create an SVG, you can use this tool to display the SVG.",
    inputSchema: .init(type: .object, properties:[
        "raw": .init(type: .string, description: "SVG content")
    ])
)

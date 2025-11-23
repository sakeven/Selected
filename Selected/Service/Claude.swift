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

public typealias ClaudeModel = Model

extension ClaudeModel: @retroactive CaseIterable {
    public static var allCases: [SwiftAnthropic.Model] {
        [.claude37Sonnet, .claude35Haiku, .claude35Sonnet]
    }
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
        index: inout Int,
        toolUseList: [ToolUse],
        with functionDefinitions: [FunctionDefinition],
        options: [String: String],
        completion: @escaping (_: Int, _: ResponseMessage) -> Void
    ) async throws -> [MessageParameter.Message] {
        index += 1
        var fcSet = [String: FunctionDefinition]()
        for fc in functionDefinitions {
            fcSet[fc.name] = fc
        }
        var toolUseResults = [MessageParameter.Message.Content.ContentObject]()

        for tool in toolUseList {
            if tool.name == "display_svg" {
                let rawMessage = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
                var message = ResponseMessage(message: rawMessage, role: .assistant, new: true, status: .updating)
                completion(index, message)
                // 打开 SVG 浏览器预览
                _ = openSVGInBrowser(svgData: tool.input)
                message = ResponseMessage(message: String(format: NSLocalizedString("display_svg", comment: "")), role: .assistant, new: true, status: .finished)
                completion(index, message)
                toolUseResults.append(.toolResult(tool.id, "display svg successfully"))
                continue
            }

            guard let fc = fcSet[tool.name] else { continue }
            let rawMessage = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
            let message = ResponseMessage(message: rawMessage, role: .assistant, new: true, status: .updating)
            if let template = fc.template {
                message.message = renderTemplate(templateString: template, json: tool.input)
            }
            completion(index, message)

            if let ret = try fc.Run(arguments: tool.input, options: options) {
                let resultMessage = ResponseMessage(message: ret, role: .assistant, new: true, status: .finished)
                if let show = fc.showResult, !show {
                    resultMessage.message = fc.template != nil ? "" : String(format: NSLocalizedString("called_tool", comment: "tool message"), fc.name)
                }
                completion(index, resultMessage)
                toolUseResults.append(.toolResult(tool.id, ret))
            }
        }
        return [.init(role: .user, content: .list(toolUseResults))]
    }
}

// MARK: - 查询管理模块

struct QueryManager {
    private(set) var query: MessageParameter
    private let _tools: [MessageParameter.Tool]

    init(model: Model, systemPrompt: String, tools: [MessageParameter.Tool]) {
        var thinking: MessageParameter.Thinking? = nil
        if model.value == Model.claude37Sonnet.value {
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

class ClaudeService: AIChatService {
    private let service: AnthropicService
    private let prompt: String
    private let options: [String: String]
    private var queryManager: QueryManager
    private let tools: [FunctionDefinition]?

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:]) {
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
        self.queryManager = QueryManager(model: .other(Defaults[.claudeModel]), systemPrompt: systemPrompt(), tools: toolsParam)
    }

    /// 单次聊天：仅发送一条消息，返回流式响应内容
    func chatOne(selectedText: String, completion: @escaping (_: String) -> Void) async {
        let userMessage = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        let parameters = MessageParameter(
            model: .claude35Sonnet,
            messages: [.init(role: .user, content: .text(userMessage))],
            maxTokens: 4096
        )
        do {
            let stream = try await service.streamMessage(parameters)
            for try await result in stream {
                let content = result.delta?.text ?? ""
                if !content.isEmpty {
                    completion(content)
                }
            }
        } catch {
            print("claude error \(error)")
        }
    }

    /// 聊天跟进：追加用户消息，并循环处理直到得到完整回复
    func chatFollow(index: Int, userMessage: String, completion: @escaping (_: Int, _: ResponseMessage) -> Void) async {
        queryManager.update(with: .init(role: .user, content: .text(userMessage)))
        var newIndex = index
        while let last = queryManager.query.messages.last, last.role != MessageParameter.Message.Role.assistant.rawValue {
            do {
                try await chatOneRound(index: &newIndex, completion: completion)
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

    /// 根据聊天上下文进行整体对话
    func chat(ctx: ChatContext, completion: @escaping (_: Int, _: ResponseMessage) -> Void) async {
        var userMessage = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        userMessage = replaceOptions(content: userMessage, selectedText: ctx.text, options: options)
        queryManager.update(with: .init(role: .user, content: .text(userMessage)))
        var index = -1
        while let last = queryManager.query.messages.last, last.role != MessageParameter.Message.Role.assistant.rawValue {
            do {
                try await chatOneRound(index: &index, completion: completion)
            } catch {
                index += 1
                let localMsg = String(format: NSLocalizedString("error_exception", comment: "system info"), error as CVarArg)
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                completion(index, message)
                return
            }
            if index >= MAX_CHAT_ROUNDS {
                index += 1
                let localMsg = NSLocalizedString("Too much rounds, please start a new chat", comment: "system info")
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                completion(index, message)
                return
            }
        }
    }

    /// 单轮聊天处理：流式接收回复，并处理可能的工具调用
    private func chatOneRound(index: inout Int, completion: @escaping (_: Int, _: ResponseMessage) -> Void) async throws {
        print("index is \(index)")
        var assistantMessage = ""
        var thinking = ""
        var toolParameters = ""
        var signature = ""
        var toolUseList = [ToolUse]()
        var lastToolUseBlockIndex = -1

        completion(index + 1, ResponseMessage(message: NSLocalizedString("waiting", comment: "system info"), role: .system, new: true, status: .initial))
        var appendIndex = false
        let stream = try await service.streamMessage(queryManager.query)
        for try await result in stream {
            let content = result.delta?.text ?? ""
            if !content.isEmpty {
                if !appendIndex {
                    index += 1
                    appendIndex = true
                }
                completion(index, ResponseMessage(message: content, role: .assistant, new: assistantMessage.isEmpty, status: .updating))
                assistantMessage += content
            }

            thinking += result.delta?.thinking ?? ""
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

        if !assistantMessage.isEmpty {
            completion(index, ResponseMessage(message: "", role: .assistant, new: false, status: .finished))
        }

        var contents = [MessageParameter.Message.Content.ContentObject]()
        contents.append(.text(assistantMessage))
        if !thinking.isEmpty {
            contents.append(.thinking(thinking, signature))
        }

        // 将工具调用封装到查询记录中
        for tool in toolUseList {
            let input = try JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self, from: tool.input.data(using: .utf8)!)
            contents.append(.toolUse(tool.id, tool.name, input))
        }
        queryManager.update(with: .init(role: .assistant, content: .list(contents)))

        // 调用工具，并将工具结果追加到查询记录
        if let functions = tools, !toolUseList.isEmpty {
            let toolMessages = try await ToolsManager.callTools(index: &index, toolUseList: toolUseList, with: functions, options: options, completion: completion)
            if !toolMessages.isEmpty {
                queryManager.update(with: toolMessages)
            }
        }
    }
}

let ClaudeWordTrans = ClaudeService(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let ClaudeTrans2Chinese = ClaudeService(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}")

let ClaudeTrans2English = ClaudeService(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")


let svgToolClaudeDef = MessageParameter.Tool.function(
    name: "display_svg",
    description: "When user requests you to create an SVG, you can use this tool to display the SVG.",
    inputSchema: .init(type: .object, properties:[
        "raw": .init(type: .string, description: "SVG content")
    ])
)

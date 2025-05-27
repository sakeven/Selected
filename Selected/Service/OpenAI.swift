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
    static let gpt4_1 = "gpt-4.1"
    static let gpt4_1_mini = "gpt-4.1-mini"

    static let o4_mini = "o4-mini"
    static let o3 = "o3"
}

let OpenAIModels: [Model] = [.gpt4_1, .gpt4_1_mini, .o4_mini, .o3, .gpt4_o, .gpt4_o_mini, .o1, .o1_mini, .o3_mini]
let OpenAITTSModels: [Model] = [.gpt_4o_mini_tts, .tts_1, .tts_1_hd]
let OpenAITranslationModels: [Model] = [.gpt4_1_mini, .gpt4_o, .gpt4_o_mini]

func isReasoningModel(_ model: Model) -> Bool {
    return [.o4_mini, .o3, .o1, .o3_mini].contains(model)
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

class OpenAIService: AIChatService{
    private let prompt: String
    private var tools: [FunctionDefinition]?
    private let openAI: OpenAI
    private var query: ChatQuery
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
        self.openAI = OpenAI(configuration: configuration)
        self.options = options
        self.query = OpenAIService.createQuery(functions: tools, model: Defaults[.openAIModel])
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
        self.query = OpenAIService.createQuery(functions: tools, model: model)
    }

    // 更新对话查询
    private func updateQuery(message: ChatQuery.ChatCompletionMessageParam) {
        var messages = query.messages
        messages.append(message)
        query = ChatQuery(messages: messages, model: query.model, reasoningEffort: query.reasoningEffort, tools: query.tools)
    }

    private func updateQuery(messages: [ChatQuery.ChatCompletionMessageParam]) {
        var updatedMessages = query.messages
        updatedMessages.append(contentsOf: messages)
        query = ChatQuery(messages: updatedMessages, model: query.model,  reasoningEffort: query.reasoningEffort, tools: query.tools)
    }

    /// 单轮对话，适合简单返回结果（流式返回）
    func chatOne(selectedText: String, completion: @escaping (String) -> Void) async {
        var messages = query.messages
        let messageContent = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        messages.append(.init(role: .user, content: messageContent)!)
        let query = ChatQuery(messages: messages, model: query.model, reasoningEffort: query.reasoningEffort, tools: query.tools)

        do {
            for try await result in openAI.chatsStream(query: query) {
                if result.choices[0].finishReason == nil, let content = result.choices[0].delta.content {
                    completion(content)
                }
            }
        } catch {
            print("completion error \(error)")
        }
    }

    /// 发起对话，会进行多轮聊天直至收到 assistant 的回答
    func chat(ctx: ChatContext, completion: @escaping (Int, ResponseMessage) -> Void) async {
        var messageContent = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        messageContent = replaceOptions(content: messageContent, selectedText: ctx.text, options: options)
        updateQuery(message: .init(role: .user, content: messageContent)!)

        var index = -1
        while let last = query.messages.last, last.role != .assistant {
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

    /// 处理用户后续的消息
    func chatFollow(index: Int, userMessage: String, completion: @escaping (Int, ResponseMessage) -> Void) async {
        updateQuery(message: .init(role: .user, content: userMessage)!)
        var newIndex = index
        while let last = query.messages.last, last.role != .assistant {
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

    /// 单轮聊天流程，包括流式处理和工具调用
    private func chatOneRound(index: inout Int, completion: @escaping (Int, ResponseMessage) -> Void) async throws {
        print("index is \(index)")
        var hasTools = false
        var toolCallsDict = [Int: ChatCompletionMessageToolCallParam]()
        var hasMessage = false
        var assistantMessage = ""

        completion(index + 1, ResponseMessage(message: NSLocalizedString("Waiting", comment: "system info"), role: .system, new: true, status: .initial))
        for try await result in openAI.chatsStream(query: query) {
            // 收集工具调用信息
            if let toolCalls = result.choices[0].delta.toolCalls {
                hasTools = true
                for f in toolCalls {
                    let toolCallID = f.index
                    if let existing = toolCallsDict[toolCallID] {
                        let newToolCall = ChatCompletionMessageToolCallParam(
                            id: existing.id,
                            function: .init(
                                arguments: existing.function.arguments + (f.function?.arguments ?? ""),
                                name: existing.function.name
                            )
                        )
                        toolCallsDict[toolCallID] = newToolCall
                    } else {
                        let toolCall = ChatCompletionMessageToolCallParam(
                            id: f.id!,
                            function: .init(
                                arguments: f.function?.arguments ?? "",
                                name: f.function?.name ?? ""
                            )
                        )
                        toolCallsDict[toolCallID] = toolCall
                    }
                }
            }

            // 处理 assistant 返回的内容
            if result.choices[0].finishReason == nil, let content = result.choices[0].delta.content {
                var newMessage = false
                if !hasMessage {
                    index += 1
                    hasMessage = true
                    newMessage = true
                }
                let message = ResponseMessage(message: content, role: .assistant, new: newMessage, status: .updating)
                assistantMessage += message.message
                completion(index, message)
            }
        }

        if hasMessage {
            completion(index, ResponseMessage(message: "", role: .assistant, new: false, status: .finished))
        }
        if !hasTools {
            updateQuery(message: .assistant(.init(content: assistantMessage)))
            return
        }

        var toolCalls = [OpenAIChatCompletionMessageToolCallParam]()
        for (_, tool) in toolCallsDict {
            let function = try JSONDecoder().decode(ChatFunctionCall.self, from: JSONEncoder().encode(tool.function))
            toolCalls.append(.init(id: tool.id, function: function))
        }
        updateQuery(message: .assistant(.init(content: assistantMessage, toolCalls: toolCalls)))

        let toolMessages = try await callTools(index: &index, toolCallsDict: toolCallsDict, completion: completion)
        if !toolMessages.isEmpty {
            updateQuery(messages: toolMessages)
        }
    }

    // 内部方法：调用工具函数
    private func callTools(index: inout Int, toolCallsDict: [Int: ChatCompletionMessageToolCallParam], completion: @escaping (Int, ResponseMessage) -> Void) async throws -> [ChatQuery.ChatCompletionMessageParam] {
        guard let functions = tools else { return [] }

        index += 1
        print("tool index \(index)")

        // 构建工具映射
        var functionMap = [String: FunctionDefinition]()
        for function in functions {
            functionMap[function.name] = function
        }

        var messages = [ChatQuery.ChatCompletionMessageParam]()
        for (_, tool) in toolCallsDict {
            let toolMessage = ResponseMessage(
                message: String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.function.name),
                role: .tool,
                new: true,
                status: .updating
            )
            // 如果工具定义中有模板，则渲染后更新消息
            if let funcDef = functionMap[tool.function.name],
               let template = funcDef.template {
                toolMessage.message = renderTemplate(templateString: template, json: tool.function.arguments)
                print("\(toolMessage.message)")
            }
            completion(index, toolMessage)
            print("\(tool.function.arguments)")

            // 根据工具名称调用不同的逻辑
            if tool.function.name == dalle3Def.name {
                let url = try await ImageGeneration.generateDalle3Image(openAI: openAI, arguments: tool.function.arguments)
                messages.append(.tool(.init(content: url, toolCallId: tool.id)))
                let ret = "[![this is picture](" + url + ")](" + url + ")"
                let message = ResponseMessage(message: ret, role: .tool, new: true, status: .finished)
                completion(index, message)
            } else if tool.function.name == svgToolOpenAIDef.name {
                _ = openSVGInBrowser(svgData: tool.function.arguments)
                messages.append(.tool(.init(content: "display svg successfully", toolCallId: tool.id)))
                let message = ResponseMessage(message: NSLocalizedString("display_svg", comment: ""), role: .tool, new: true, status: .finished)
                completion(index, message)
            } else {
                if let funcDef = functionMap[tool.function.name] {
                    print("call: \(tool.function.arguments)")
                    if let ret = try funcDef.Run(arguments: tool.function.arguments, options: options) {
                        let statusMessage = (funcDef.showResult ?? true)
                        ? ret
                        : String(format: NSLocalizedString("called_tool", comment: "tool message"), funcDef.name)
                        let message = ResponseMessage(message: statusMessage, role: .tool, new: true, status: .finished)
                        completion(index, message)
                        messages.append(.tool(.init(content: ret, toolCallId: tool.id)))
                    }
                }
            }
        }
        return messages
    }

    // 内部方法：根据工具列表和模型构造 ChatQuery 对象
    private static func createQuery(functions: [FunctionDefinition]?, model: OpenAIModel) -> ChatQuery {
        var tools: [ChatQuery.ChatCompletionToolParam]? = nil
        if let functions = functions {
            var toolList: [ChatQuery.ChatCompletionToolParam] = [.init(function: dalle3Def), .init(function: svgToolOpenAIDef)]
            for fc in functions {
                let fcConverted = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                    name: fc.name,
                    description: fc.description,
                    parameters: fc.getParameters()
                )
                toolList.append(.init(function: fcConverted))
            }
            tools = toolList
        }

        if model == "o1-preview" || model == .o1_mini {
            return ChatQuery(messages: [], model: model, tools: nil)
        }

        var reasoningEffort: ChatQuery.ReasoningEffort? = nil
        if isReasoningModel(model){
            reasoningEffort = switch Defaults[.openAIModelReasoningEffort]{
                case "low": .low
                case "medium": .medium
                case "high": .high
                default: .medium
            }
        }

        return ChatQuery(
            messages: [.init(role: .developer, content: systemPrompt())!],
            model: model,
            reasoningEffort: reasoningEffort,
            tools: tools
        )
    }
}

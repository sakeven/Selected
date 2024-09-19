//
//  Claude.swift
//  Selected
//
//  Created by sake on 2024/7/13.
//

import Foundation
import SwiftAnthropic
import Defaults


public typealias ClaudeModel = Model

extension ClaudeModel: @retroactive CaseIterable {
    public static var allCases: [SwiftAnthropic.Model] {
        [.claude3Opus, .claude3Haiku, .claude3Sonnet, .claude35Sonnet]
    }
}

fileprivate struct ToolUse {
    let id: String
    let name: String
    var input: String
}


fileprivate func genTools(functions: [FunctionDefinition]?) -> [MessageParameter.Tool] {
    guard let functions = functions else {
        return []
    }

    var _tools = [MessageParameter.Tool]()
    for fc in functions {
        let p = try! JSONDecoder().decode(MessageParameter.Tool.JSONSchema.self, from: fc.parameters.data(using: .utf8)!)
        let tool = MessageParameter.Tool(name: fc.name, description: fc.description, inputSchema: p)
        _tools.append(tool)
    }
    return _tools
}

fileprivate func createQuery(tools: [MessageParameter.Tool]) -> MessageParameter {
    return MessageParameter(
        model: .other(Defaults[.claudeModel]),
        messages: [],
        maxTokens: 4096,
        system: MessageParameter.System.text(systemPrompt()),
        tools: tools
    )
}

class ClaudeService: AIChatService{
    let service: AnthropicService
    let prompt: String
    let options: [String:String]
    var query: MessageParameter
    var toolsParameter: [MessageParameter.Tool]
    var tools: [FunctionDefinition]?

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String:String] = [String:String]()){
        var apiHost = "https://api.anthropic.com"
        if Defaults[.claudeAPIHost] != "" {
            apiHost = Defaults[.claudeAPIHost]
        }
        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey], basePath: apiHost, betaHeaders: nil)
        self.prompt = prompt
        self.options = options
        self.toolsParameter = genTools(functions: tools)
        self.tools = tools
        self.query = createQuery(tools: self.toolsParameter)
    }

    func chatOne(
        selectedText: String,
        completion: @escaping (_: String) -> Void) async -> Void {
            let userMessage = replaceOptions(content: prompt, selectedText: selectedText, options: options)
            let parameters = MessageParameter(model: .claude35Sonnet, messages: [.init(role: .user, content: .text(userMessage))], maxTokens: 4096)
            do {
                let stream = try await service.streamMessage(parameters)
                for try await result in stream {
                    let content = result.delta?.text ?? ""
                    if content != "" {
                        completion(content)
                    }
                }
            } catch {
                NSLog("claude error \(error)")
                return
            }
        }

    func chatFollow(
        index: Int,
        userMessage: String,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {
            updateQuery(message:.init(role: .user, content: .text(userMessage)) )
            var newIndex = index
            while let last = query.messages.last, last.role != MessageParameter.Message.Role.assistant.rawValue {
                do {
                    try await chatOneRound(index: &newIndex, completion: completion)
                } catch {
                    newIndex += 1
                    let localMsg = String(format: NSLocalizedString("error_exception", comment: "system info"), error as CVarArg)
                    let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                    completion(newIndex, message)
                    return
                }
                if newIndex-index >= 10 {
                    newIndex += 1
                    let localMsg = NSLocalizedString("Too much rounds, please start a new chat", comment: "system info")
                    let message = ResponseMessage(message: localMsg, role: .system, new: true, status:.failure)
                    completion(newIndex, message)
                    return
                }
            }
        }

    func chat(ctx: ChatContext, completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void{
        var userMessage = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        userMessage = replaceOptions(content: userMessage, selectedText: ctx.text, options: options)
        updateQuery(message: .init(role: .user, content: .text(userMessage)))

        var index = -1
        while let last = query.messages.last, last.role != MessageParameter.Message.Role.assistant.rawValue {
            do {
                try await chatOneRound(index: &index, completion: completion)
            } catch {
                index += 1
                let localMsg = String(format: NSLocalizedString("error_exception", comment: "system info"), error as CVarArg)
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status: .failure)
                completion(index, message)
                return
            }
            if index >= 10 {
                index += 1
                let localMsg = NSLocalizedString("Too much rounds, please start a new chat", comment: "system info")
                let message = ResponseMessage(message: localMsg, role: .system, new: true, status:.failure)
                completion(index, message)
                return
            }
        }
    }


    func chatOneRound(
        index: inout Int,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async throws -> Void {
            NSLog("index is \(index)")
            var assistantMessage = ""

            var toolParameters = ""
            var toolUseList = [ToolUse]()
            var lastToolUseBlockIndex = -1

            completion(index+1, ResponseMessage(message: NSLocalizedString("waiting", comment: "system info"), role: .system, new: true, status: .initial))
            let stream = try await service.streamMessage(query)
            for try await result in stream {
                let content = result.delta?.text ?? ""
                if content != "" {
                    if assistantMessage == "" {
                        index += 1
                    }
                    completion(index, ResponseMessage(message: content, role: .assistant, new: assistantMessage == "", status: .updating))
                    assistantMessage += content
                }
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
                            var toolUse = toolUseList[toolUseList.count-1]
                            toolUse.input = jsonify(toolParameters)
                            toolUseList[toolUseList.count-1] = toolUse
                        }
                    default:
                        break
                }
            }

            if !assistantMessage.isEmpty {
                completion(index, ResponseMessage(message: "", role: .assistant, new: false, status: .finished))
            }

            if toolUseList.isEmpty {
                updateQuery(message: .init(role: .assistant, content: .text(assistantMessage)))
                return
            }

            var contents =  [MessageParameter.Message.Content.ContentObject]()
            contents.append(.text(assistantMessage))
            for tool in toolUseList {
                let input =
                try JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self, from: tool.input.data(using: .utf8)!)
                contents.append(.toolUse(tool.id, tool.name, input))
            }
            updateQuery(message: .init(role: .assistant, content: .list(contents)))

            let toolMessages = try await callTools(index: &index, toolUseList: toolUseList, completion: completion)
            if toolMessages.isEmpty {
                return
            }
            updateQuery(messages: toolMessages)
        }

    func updateQuery(message: MessageParameter.Message) {
        var messages = query.messages
        messages.append(message)
        query = MessageParameter(
            model: .other(query.model),
            messages: messages,
            maxTokens: 4096,
            system: query.system,
            tools: toolsParameter
        )
    }

    func updateQuery(messages: [MessageParameter.Message]) {
        var _messages = query.messages
        _messages.append(contentsOf: messages)
        query = MessageParameter(
            model: .other(query.model),
            messages: _messages,
            maxTokens: 4096,
            system: query.system,
            tools: toolsParameter
        )
    }

    private func callTools(
        index: inout Int,
        toolUseList: [ToolUse],
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async throws -> [MessageParameter.Message] {
            guard let fcs = tools else {
                return []
            }

            index += 1
            NSLog("tool index \(index)")

            var fcSet = [String: FunctionDefinition]()
            for fc in fcs {
                fcSet[fc.name] = fc
            }

            var messages = [MessageParameter.Message]()

            var toolUseResults = [MessageParameter.Message.Content.ContentObject]()
            for tool in toolUseList {
                guard let f = fcSet[tool.name] else {
                    continue
                }

                let rawMessage = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
                let message =  ResponseMessage(message: rawMessage, role: .tool, new: true, status: .updating)
                if let template = f.template {
                    message.message =  renderTemplate(templateString: template, json: tool.input)
                    NSLog("\(message.message)")
                }

                completion(index, message)

                if let ret = try f.Run(arguments: tool.input, options: options) {
                    let message = ResponseMessage(message: ret, role: .tool, new: true, status: .finished)
                    if let show = f.showResult, !show {
                        if f.template != nil {
                            message.message = ""
                            message.new = false
                        } else {
                            message.message = String(format: NSLocalizedString("called_tool", comment: "tool message"), f.name)
                        }
                    }
                    completion(index, message)
                    toolUseResults.append(.toolResult(tool.id, ret))
                }
            }
            messages.append(.init(role: .user, content: .list(toolUseResults)))
            return messages
        }
}

let ClaudeWordTrans = ClaudeService(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let ClaudeTrans2Chinese = ClaudeService(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}")

let ClaudeTrans2English = ClaudeService(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

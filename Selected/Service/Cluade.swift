//
//  Cluade.swift
//  Selected
//
//  Created by sake on 2024/7/13.
//

import Foundation
import SwiftAnthropic
import Defaults


fileprivate struct ToolUse {
    let id: String
    let name: String
    var input: String
}


fileprivate func genTools(functions: [FunctionDefinition]?) -> [MessageParameter.Tool] {
    guard let functions = functions else {
        return []
    }

    //        var _tools: [ChatQuery.ChatCompletionToolParam] = [.init(function: dalle3Def)]
    var _tools = [MessageParameter.Tool]()
    for fc in functions {
        let p = try! JSONDecoder().decode(MessageParameter.Tool.JSONSchema.self, from: fc.parameters.data(using: .utf8)!)
        let tool = MessageParameter.Tool(name: fc.name, description: fc.description, inputSchema: p)
        _tools.append(tool)
    }
    return _tools
}

fileprivate func createQuery(tools: [MessageParameter.Tool]) -> MessageParameter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let localDate = dateFormatter.string(from: Date())

    let language = getCurrentAppLanguage()
    var currentLocation = ""
    if let location = LocationManager.shared.place {
        currentLocation = "I'm at \(location)"
    }
    let systemPrompt = """
                      Current time is \(localDate).
                      \(currentLocation)
                      You are a tool running on macOS called Selected. You can help user do anything.
                      The system language is \(language), you should try to reply in \(language) as much as possible, unless the user specifies to use another language, such as specifying to translate into a certain language.
                      """

    // 通过 Swift 获取当前应用的语言
    return MessageParameter(
        model: .claude35Sonnet,
        messages: [],
        maxTokens: 4096,
        system: systemPrompt,
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
        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey])
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
                NSLog("cluade error \(error)")
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
                    let message = ResponseMessage(message: "exception: \(error)", role: "system", new: true)
                    completion(newIndex, message)
                    return
                }
                if newIndex-index >= 10 {
                    NSLog("call too much")
                    newIndex += 1
                    let message = ResponseMessage(message: "too much rounds, please start a new chat", role: "system", new: true)
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
                let message = ResponseMessage(message: "exception: \(error)", role: "system", new: true)
                completion(index, message)
                return
            }
            if index >= 10 {
                index += 1
                NSLog("call too much")
                let message = ResponseMessage(message: "too much rounds, please start a new chat", role: "system", new: true)
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

            let stream = try await service.streamMessage(query)
            for try await result in stream {
                let content = result.delta?.text ?? ""
                if content != "" {
                    if assistantMessage == "" {
                        index += 1
                    }
                    completion(index, ResponseMessage(message: content, role: "assistant", new: assistantMessage == ""))
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
//                            index += 1
//                            completion(index, ResponseMessage(message: toolUse.input, role: "tool"))
                        }
                    default:
                        break
                }
            }

            if toolUseList.isEmpty {
                updateQuery(message: .init(role: .assistant, content: .text(assistantMessage)))
                return
            }

            var contents =  [MessageParameter.Message.Content.ContentObject]()
            contents.append(.text(assistantMessage))
            for tool in toolUseList {
                let input =
                try! JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self , from: tool.input.data(using: .utf8)!)

                contents.append(.toolUse(tool.id, tool.name, input))
            }
            updateQuery(message: .init(role: .assistant, content: .list(contents)))

            let toolMessages = await callTools(index: &index, toolUseList: toolUseList, completion: completion)
            if toolMessages.isEmpty {
                return
            }
            updateQuery(messages: toolMessages)
        }

    func updateQuery(message: MessageParameter.Message) {
        var messages = query.messages
        messages.append(message)
        query = MessageParameter(
            model: .claude35Sonnet,
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
            model: .claude35Sonnet,
            messages: _messages,
            maxTokens: 4096,
            system: query.system,
            tools: toolsParameter
        )
    }

    private func callTools(
        index: inout Int,
        toolUseList: [ToolUse],
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> [MessageParameter.Message] {
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
                let message =  ResponseMessage(message: "Calling \(tool.name)...", role: "tool", new: true)

                if let f = fcSet[tool.name] {
                    if let template = f.template {
                        message.message =  renderTemplate(templateString: template, json: tool.input)
                        NSLog("\(message.message)")
                    }
                }
                completion(index, message)
                NSLog("\(tool.input)")

                if let f = fcSet[tool.name] {
                    if let ret = f.Run(arguments: tool.input, options: options) {
                        let message = ResponseMessage(message: ret, role: "tool",  new: true)
                        if let show = f.showResult, !show {
                            if f.template != nil {
                                message.message = ""
                                message.new = false
                            } else {
                                message.message = "\(f.name) called"
                            }
                        }
                        completion(index, message)
                        toolUseResults.append(.toolResult(tool.id, ret))
                    } else {
                        NSLog("call function not return result")
                        return []
                    }
                }
            }
            messages.append(.init(role: .user, content: .list(toolUseResults)))
            return messages
        }
}

let ClaudeWordTrans = ClaudeService(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let ClaudeTrans2Chinese = ClaudeService(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}")

let ClaudeTrans2English = ClaudeService(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

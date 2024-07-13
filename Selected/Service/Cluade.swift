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

struct ClaudeService: AIChatService{
    let service: AnthropicService
    let prompt: String
    let options: [String:String]


    init(prompt: String, options: [String:String] = [String:String](), tools: [FunctionDefinition]? = nil){
        service = AnthropicServiceFactory.service(apiKey: Defaults[.claudeAPIKey])
        self.prompt = prompt
        self.options = options
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

    func chat(ctx: ChatContext, completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void{
        var userMessage = renderChatContent(content: prompt, chatCtx: ctx, options: options)
        userMessage = replaceOptions(content: userMessage, selectedText: ctx.text, options: options)
        let parameters = MessageParameter(model: .claude35Sonnet, messages: [.init(role: .user, content: .text(userMessage))], maxTokens: 4096)
        var message = ""
        var toolParameters = ""
        var toolUseList = [ToolUse]()
        var lastToolUseBlockIndex = -1

        var index = 1
        do {
            let stream = try await service.streamMessage(parameters)
            for try await result in stream {
                let content = result.delta?.text ?? ""
                message += content
                if content != "" {
                    completion(index, ResponseMessage(message: content, role: "assistant"))
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
                            toolUse.input = toolParameters
                            toolUseList[toolUseList.count-1] = toolUse
                            index += 1
                            completion(index, ResponseMessage(message: toolParameters, role: "tool"))
                        }
                    default:
                        break
                }
            }
        } catch {
            NSLog("cluade error \(error)")
            return
        }
        NSLog("message: \(message) toolParameters: \(toolParameters) toolUse: \(toolUseList)")
    }

    func chatFollow(
        index: Int,
        userMessage: String,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {

        }
}

let ClaudeWordTrans = ClaudeService(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let ClaudeTrans2Chinese = ClaudeService(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}")

let ClaudeTrans2English = ClaudeService(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

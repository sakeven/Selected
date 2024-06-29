//
//  AI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import Defaults
import SwiftUI
import OpenAI

func isWord(str: String) -> Bool {
    for c in str {
        if c.isLetter || c == "-" {
            continue
        }
        return false
    }
    return true
}

struct Translation {
    let toLanguage: String
    
    func translate(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        if toLanguage == "cn" {
            await contentTrans2Chinese(content: content, completion: completion)
        } else if toLanguage == "en" {
            await contentTrans2English(content: content, completion: completion)
        }
    }
    
    private func isWord(str: String) -> Bool {
        for c in str {
            if c.isLetter || c == "-" {
                continue
            }
            return false
        }
        return true
    }
    
    private func contentTrans2Chinese(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                NSLog("OpenAI")
                if isWord(str: content) {
                    await OpenAIWordTrans.chatOne(selectedText: content, completion: completion)
                } else {
                    await OpenAITrans2Chinese.chatOne(selectedText: content, completion: completion)
                }
            case "Gemini":
                NSLog("Gemini")
                if isWord(str: content) {
                    await GeminiWordTrans.chatOne(selectedText: content, completion: completion)
                } else {
                    await GeminiTrans2Chinese.chatOne(selectedText: content, completion: completion)
                }
            default: break
//                completion("no model \(Defaults[.aiService]))
        }
    }
    
    private func contentTrans2English(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                NSLog("OpenAI")
                await OpenAITrans2English.chatOne(selectedText: content, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiTrans2English.chatOne(selectedText: content, completion: completion)
            default: break

//                completion("no model \(Defaults[.aiService])")
        }
    }

    private func convert(index: Int, message: ResponseMessage)->Void {

    }
}

struct ChatService: AIChatService{
    let prompt: String

    func chat(content: String, options: [String:String], completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                var openai = OpenAIPrompt(prompt: prompt)
                await openai.chat(selectedText: content, options: options, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiPrompt(prompt: prompt).chat(selectedText: content, options: options, completion: completion)
            default: break
//                completion("no model \(Defaults[.aiService])")
        }
    }

    func GetAllQueryMessages() -> [ChatQuery.ChatCompletionMessageParam] {
        return []
    }
}


class OpenAIService: AIChatService{
    var openAI: OpenAIPrompt


    init(prompt: String, tools: [FunctionDefinition]? = nil) {
        var fcs = [FunctionDefinition]()
        if let tools = tools {
            fcs.append(contentsOf: tools)
        }
        openAI = OpenAIPrompt(prompt: prompt, tools: fcs)
    }

    func chat(content: String, options: [String:String], completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void{
        await openAI
            .chat(selectedText: content, options: options, completion: completion)
    }
}


public protocol AIChatService {
    func chat(content: String, options: [String:String], completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void
}


public class ResponseMessage: ObservableObject, Identifiable{
    public var id = UUID()
    @Published var message: String
    @Published var role: String
    var new: Bool = false // new start of message

    init(id: UUID = UUID(), message: String, role: String, new: Bool = false) {
        self.id = id
        self.message = message
        self.role = role
        self.new = new
    }
}

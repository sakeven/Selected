//
//  AI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import Defaults
import SwiftUI



struct Translation {
    let toLanguage: String
    
    func translate(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        if toLanguage == "cn" {
            await contentTrans2Cn(content: content, completion: completion)
        } else if toLanguage == "en" {
            await contentTrans2En(content: content, completion: completion)
        }
    }
    
    
    func contentTrans2Cn(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                NSLog("OpenAI")
                if isWord(str: content) {
                    await OpenAIWordTrans.chat(content: content, completion: completion)
                } else {
                    await OpenAITrans2Chinese.chat(content: content, completion: completion)
                }
            case "Gemini":
                NSLog("Gemini")
                if isWord(str: content) {
                    await GeminiWordTrans.chat(content: content, completion: completion)
                } else {
                    await GeminiTrans2CN.chat(content: content, completion: completion)
                }
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
    
    func contentTrans2En(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                NSLog("OpenAI")
                await OpenAITrans2English.chat(content: content, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiTrans2EN.chat(content: content, completion: completion)
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
}

struct ChatService {
    let prompt: String
    
    func chat(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                await OpenAIPrompt(prompt: prompt).chat(content: content, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiPrompt(prompt: prompt).chat(content: content, completion: completion)
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
}

//
//  AI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import Defaults
import SwiftUI

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
                    await OpenAIWordTrans.chat(selectedText: content, completion: completion)
                } else {
                    await OpenAITrans2Chinese.chat(selectedText: content, completion: completion)
                }
            case "Gemini":
                NSLog("Gemini")
                if isWord(str: content) {
                    await GeminiWordTrans.chat(selectedText: content, completion: completion)
                } else {
                    await GeminiTrans2Chinese.chat(selectedText: content, completion: completion)
                }
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
    
    private func contentTrans2English(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                NSLog("OpenAI")
                await OpenAITrans2English.chat(selectedText: content, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiTrans2English.chat(selectedText: content, completion: completion)
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
}

struct ChatService {
    let prompt: String
    
    func chat(content: String, options: [String:String], completion: @escaping (_: String) -> Void) async -> Void{
        switch Defaults[.aiService] {
            case "OpenAI":
                await OpenAIPrompt(prompt: prompt).chat(selectedText: content, options: options, completion: completion)
            case "Gemini":
                NSLog("Gemini")
                await GeminiPrompt(prompt: prompt).chat(selectedText: content, options: options, completion: completion)
            default:
                completion("no model \(Defaults[.aiService])")
        }
    }
}


struct OpenAIService {
    let prompt: String
    var functionDef: FunctionDefinition?
    
    func chat(content: String, options: [String:String], completion: @escaping (_: String) -> Void) async -> Void{
        await OpenAIPrompt(prompt: prompt, function: functionDef)
            .chat(selectedText: content, options: options, completion: completion)
    }
}

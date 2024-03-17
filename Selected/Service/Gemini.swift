//
//  Gemini.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import SwiftUI
import Defaults
import GoogleGenerativeAI

struct GeminiPrompt {
    let prompt: String
    
    func chat(content: String, completion: @escaping (_: String) -> Void) async -> Void {
        let model = GenerativeModel(name: "gemini-pro", apiKey: Defaults[.geminiAPIKey] )
      
        var message = prompt
        message.replace("{text}", with: content)
        let contentStream = model.generateContentStream(message)
        do {
            for try await chunk in contentStream {
                if let text = chunk.text {
                    NSLog(text)
                    completion(text)
                }
            }
        } catch {
            NSLog("Unexpected error: \(error).")
        }
    }
}

let GeminiWordTrans = OpenAIPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出例句。使用 markdown 的格式回复。单词为：{text}")

let GeminiTrans2CN = OpenAIPrompt(prompt:"翻译以下内容到中文。内容为：{text}")

let GeminiTrans2EN = OpenAIPrompt(prompt:"翻译以下内容到英文。内容为：{text}")

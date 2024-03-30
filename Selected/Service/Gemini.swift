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
        let model = GenerativeModel(name: "gemini-pro", apiKey: Defaults[.geminiAPIKey], requestOptions: RequestOptions(apiVersion: "v1beta") )
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

let GeminiWordTrans = GeminiPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复。单词为：{text}")

let GeminiTrans2Chinese = GeminiPrompt(prompt:"翻译以下内容到中文。内容为：{text}")

let GeminiTrans2English = GeminiPrompt(prompt:"Translate the following content into English. The content is：{text}")

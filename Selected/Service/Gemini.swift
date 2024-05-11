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
    
    func chat(selectedText: String, options: [String:String] = [String:String](), completion: @escaping (_: String) -> Void) async -> Void {
        
        let model = GenerativeModel(name: "gemini-1.5-pro-latest", apiKey: Defaults[.geminiAPIKey], requestOptions: RequestOptions(apiVersion: "v1beta") )
        let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        
        NSLog("prompt is \(message)")
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

let GeminiWordTrans = GeminiPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let GeminiTrans2Chinese = GeminiPrompt(prompt:"翻译以下内容到中文。内容为：{selected.text}")

let GeminiTrans2English = GeminiPrompt(prompt:"Translate the following content into English. The content is：{selected.text}")

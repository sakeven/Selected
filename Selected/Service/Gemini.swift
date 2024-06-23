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

    func chat(
        selectedText: String,
        options: [String:String] = [String:String](),
        completion: @escaping (_ : Int, _: ResponseMessage) -> Void) async -> Void {

            let model = GenerativeModel(name: "gemini-1.5-pro-latest", apiKey: Defaults[.geminiAPIKey], requestOptions: RequestOptions(apiVersion: "v1beta") )
            let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)

            NSLog("prompt is \(message)")
            let contentStream = model.generateContentStream(message)
            do {
                for try await chunk in contentStream {
                    if let text = chunk.text {
                        NSLog(text)
                        let message = ResponseMessage(message: text, role: "assistant")
                        completion(0, message)
                    }
                }
            } catch {
                NSLog("Unexpected error: \(error).")
            }
        }

    func chatOne(
        selectedText: String,
        options: [String:String] = [String:String](),
        completion: @escaping (_: String) -> Void) async -> Void {

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

let GeminiTrans2Chinese = GeminiPrompt(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则： 请直接回复翻译后的内容。内容为：{selected.text}")

let GeminiTrans2English = GeminiPrompt(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

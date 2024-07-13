//
//  Gemini.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import SwiftUI
import Defaults
import GoogleGenerativeAI

struct GeminiPrompt: AIChatService{
    let prompt: String
    let options: [String:String]

    init(prompt: String, options: [String:String] = [String:String]()) {
        self.prompt = prompt
        self.options = options
    }

    func chat(
        ctx: ChatContext,
        completion: @escaping (_ : Int, _: ResponseMessage) -> Void) async -> Void {

            let model = GenerativeModel(name: "gemini-1.5-pro-latest", apiKey: Defaults[.geminiAPIKey], requestOptions: RequestOptions(apiVersion: "v1beta") )
            var message = renderChatContent(content: prompt, chatCtx: ctx, options: options)
            message = replaceOptions(content: message, selectedText: ctx.text, options: options)

            let contentStream = model.generateContentStream(message)
            var resp = ""
            completion(0, ResponseMessage(message: NSLocalizedString("waiting", comment: "system info"), role: .system, new: true, status: .initial))
            do {
                for try await chunk in contentStream {
                    if let text = chunk.text {
                        NSLog(text)
                        completion(0, ResponseMessage(message: text, role: .assistant, new: resp == "" ,status: .updating))
                        resp += text
                    }
                }
            } catch {
                NSLog("Unexpected error: \(error).")
                return
            }
            completion(0, ResponseMessage(message: "", role: .assistant, new: false, status: .finished))
        }

    func chatOne(
        selectedText: String,
        completion: @escaping (_: String) -> Void) async -> Void {

            let model = GenerativeModel(name: "gemini-1.5-pro-latest", apiKey: Defaults[.geminiAPIKey], requestOptions: RequestOptions(apiVersion: "v1beta") )
            let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)

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

    func chatFollow(
        index: Int,
        userMessage: String,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {
    }
}

let GeminiWordTrans = GeminiPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let GeminiTrans2Chinese = GeminiPrompt(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则： 请直接回复翻译后的内容。内容为：{selected.text}")

let GeminiTrans2English = GeminiPrompt(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

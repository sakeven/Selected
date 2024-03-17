//
//  OpenAI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import OpenAI
import Defaults
import SwiftUI

struct OpenAIPrompt {
    let prompt: String
    
    func chat(content: String, completion: @escaping (_: String) -> Void) async -> Void {
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        
        var message = prompt
        message.replace("{text}", with: content)
        let query = ChatQuery(model: .gpt3_5Turbo, messages: [.init(role: .user, content: message)])
        
        openAI.chatsStream(query: query) { partialResult in
            switch partialResult {
                case .success(let result):
                    if result.choices[0].finishReason.isNil{
                        completion(result.choices[0].delta.content!)
                    }
                case .failure(let error):
                    NSLog("chunk error \(error)")
            }
        } completion: { error in
            NSLog("completion error \(String(describing: error))")
        }
    }
}

let OpenAIWordTrans = OpenAIPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出例句。使用 markdown 的格式回复。单词为：{text}")

let OpenAITrans2CN = OpenAIPrompt(prompt:"翻译以下内容到中文。内容为：{text}")

let OpenAITrans2EN = OpenAIPrompt(prompt:"翻译以下内容到英文。内容为：{text}")

func transByOpenAI(word: String, completion: @escaping (_: String) -> Void) async -> Void {
    let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
    let openAI = OpenAI(configuration: configuration)
    
    var prompt = "翻译以下单词到中文，详细说明单词的不同意思，并且给出例句。使用 markdown 的格式回复。单词为：\(word)"
    if !isWord(str: word) {
        prompt = "翻译以下内容到中文，使用 markdown 的格式回复。内容为：\(word)"
    }
    
    let query = ChatQuery(model: .gpt3_5Turbo, messages: [.init(role: .user, content: prompt)])
    
    openAI.chatsStream(query: query) { partialResult in
        switch partialResult {
            case .success(let result):
                if result.choices[0].finishReason.isNil{
                    completion(result.choices[0].delta.content!)
                }
            case .failure(let error):
                NSLog("chunk error \(error)")
        }
    } completion: { error in
        NSLog("completion error \(String(describing: error))")
    }
}


func trans2ENByOpenAI(content: String, completion: @escaping (_: String) -> Void) async -> Void {
    let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
    let openAI = OpenAI(configuration: configuration)
    
    
    let prompt = "翻译以下内容到英文。内容为：\(content)"
    
    
    let query = ChatQuery(model: .gpt3_5Turbo, messages: [.init(role: .user, content: prompt)])
    
    openAI.chatsStream(query: query) { partialResult in
        switch partialResult {
            case .success(let result):
                if result.choices[0].finishReason.isNil{
                    completion(result.choices[0].delta.content!)
                }
            case .failure(let error):
                NSLog("chunk error \(error)")
        }
    } completion: { error in
        NSLog("completion error \(String(describing: error))")
    }
}


func isWord(str: String) -> Bool {
    for c in str {
       if c.isLetter || c == "-" {
            continue
        }
        return false
    }
    return true
}

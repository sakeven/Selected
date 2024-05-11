//
//  OpenAI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import OpenAI
import Defaults
import SwiftUI
import AVFoundation

public extension Model {
    /// `gpt-4-turbo`, the latest gpt-4 model with improved instruction following, JSON mode, reproducible outputs, parallel function calling and more. Maximum of 4096 output tokens
    static let gpt4_turbo = "gpt-4-turbo"
}

let OpenAIModels: [Model] = [.gpt4_turbo, .gpt4, .gpt4_32k, .gpt3_5Turbo, .gpt3_5Turbo_16k]

struct OpenAIPrompt {
    let prompt: String
    
    func chat(selectedText: String, options: [String:String] = [String:String](), completion: @escaping (_: String) -> Void) async -> Void {
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        
        
        let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        let query = ChatQuery(messages: [.init(role: .user, content: message)!], model: Defaults[.openAIModel])
        
        do {
            for try await result in openAI.chatsStream(query: query) {
                if result.choices[0].finishReason.isNil{
                    completion(result.choices[0].delta.content!)
                }
            }
        } catch {
            NSLog("completion error \(String(describing: error))")
        }
    }
}

let OpenAIWordTrans = OpenAIPrompt(prompt: "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}")

let OpenAITrans2Chinese = OpenAIPrompt(prompt:"翻译以下内容到中文。内容为：{selected.text}")

let OpenAITrans2English = OpenAIPrompt(prompt:"Translate the following content into English. The content is：{selected.text}")

internal var audioPlayer: AVAudioPlayer?

private struct VoiceData {
    var data: Data
    var lastAccessTime: Date
}

private var voiceDataCache = [Int: VoiceData]()

// TODO: regular cleaning
private func clearExpiredVoiceData() {
    for (k, v) in voiceDataCache {
        if v.lastAccessTime.addingTimeInterval(120) < Date() {
            voiceDataCache.removeValue(forKey: k)
        }
    }
}

func openAITTS(_ text: String) async {
    clearExpiredVoiceData()
    if let data = voiceDataCache[text.hash] {
        NSLog("cached tts")
        audioPlayer?.stop()
        audioPlayer = try! AVAudioPlayer(data: data.data)
        audioPlayer!.play()
        return
    }
    
    let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
    let openAI = OpenAI(configuration: configuration)
    let query = AudioSpeechQuery(model: .tts_1, input: text, voice: Defaults[.openAIVoice], responseFormat: .mp3, speed: 1.0)
    
    do {
        let result = try await openAI.audioCreateSpeech(query: query)
        voiceDataCache[text.hash] = VoiceData(data: result.audio , lastAccessTime: Date())
        audioPlayer?.stop()
        audioPlayer = try! AVAudioPlayer(data:  result.audio)
        audioPlayer!.play()
    } catch {
        NSLog("audioCreateSpeech \(error)")
        return
    }
}

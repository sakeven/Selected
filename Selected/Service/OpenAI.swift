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
    /// GPT-4o (“o” for “omni”) is most advanced model. It is multimodal (accepting text or image inputs and outputting text), and it has the same high intelligence as GPT-4 Turbo but is much more efficient—it generates text 2x faster and is 50% cheaper.
    static let gpt_4o = "gpt-4o"
}

let OpenAIModels: [Model] = [.gpt4_turbo, .gpt3_5Turbo, .gpt_4o]

struct FunctionDefinition: Codable, Equatable{
    public let name: String
    
    /// The description of what the function does.
    public let description: String
    public let parameters: String
    public var command: [String]?
    public var workdir: String?
    
    func Run(arguments: String) -> String? {
        guard let command = self.command else {
            return nil
        }
        var args = [String](command[1...])
        args.append(arguments)
        return executeCommand(workdir: workdir!, command: command[0], arguments: args, withEnv: [:])
    }
    
    func getParameters() -> FunctionParameters?{
        let p = try! JSONDecoder().decode(FunctionParameters.self, from: self.parameters.data(using: .utf8)!)
        return p
    }
}

let dalle3Def = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "dalle3",
    description: "Whenever a description of an image is given, create a prompt that dalle can use to generate the image. The prompt must be in English. Translate to English if needed. The url of the image will be returned. Must display image after the tool called.",
    parameters: .init(type: .object, properties:[
        "prompt": .init(type: .string, description: "the generated prompt sent to dalle3")
    ])
)


typealias ChatFunctionCall = OpenAIChatCompletionMessageToolCallParam.FunctionCall
typealias OpenAIChatCompletionMessageToolCallParam = ChatQuery.ChatCompletionMessageParam.ChatCompletionAssistantMessageParam.ChatCompletionMessageToolCallParam
typealias FunctionParameters = ChatQuery.ChatCompletionToolParam.FunctionDefinition.FunctionParameters


struct OpenAIPrompt {
    let prompt: String
    var function: FunctionDefinition?
    
    func chat(selectedText: String, options: [String:String] = [String:String](), completion: @escaping (_: String) -> Void) async -> Void {
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        
        let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        
        var tools: [ChatQuery.ChatCompletionToolParam] = [.init(function: dalle3Def)]
        if let function = function {
            let fc = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                name: function.name,
                description: function.description,
                parameters: function.getParameters()
            )
            tools.append(.init(function: fc))
        }
        let query = ChatQuery(
            messages: [
                .init(role: .user, content: message)!],
            model: Defaults[.openAIModel],
            tools: tools
        )
        
        var hasTools = false
        var toolCallsDict = [Int: ChatCompletionMessageToolCallParam]()
        do {
            for try await result in openAI.chatsStream(query: query) {
                if let toolCalls = result.choices[0].delta.toolCalls {
                    hasTools = true
                    for f in toolCalls {
                        let toolCallID = f.index
                        if var toolCall = toolCallsDict[toolCallID] {
                            toolCall.function.arguments = toolCall.function.arguments + f.function!.arguments!
                            toolCallsDict[toolCallID] = toolCall
                        } else {
                            let toolCall = ChatCompletionMessageToolCallParam(id: f.id!, function: .init(arguments: f.function!.arguments!, name: f.function!.name!))
                            toolCallsDict[toolCallID] = toolCall
                        }
                    }
                }
                
                if result.choices[0].finishReason.isNil && result.choices[0].delta.content != nil {
                    completion(result.choices[0].delta.content!)
                }
            }
        } catch {
            NSLog("completion error \(String(describing: error))")
            return
        }
        
        if !hasTools {
            return
        }
        
        var messages = query.messages
        var callTools  =  [OpenAIChatCompletionMessageToolCallParam]()
        for (_, tool) in toolCallsDict {
            let function =
            try! JSONDecoder().decode(ChatFunctionCall.self, from: JSONEncoder().encode(tool.function))
            callTools.append(.init(id: tool.id, function: function))
        }
        messages.append(.assistant(.init(toolCalls: callTools)))
        
        for (_, tool) in toolCallsDict {
            if tool.function.name == "dalle3" {
                NSLog("\(tool.function.arguments)")
                do {
                    let url = try await dalle3(openAI: openAI, arguments: tool.function.arguments)
                    messages.append(.tool(.init(content: url, toolCallId: tool.id)))
                } catch {
                    NSLog("call function error \(String(describing: error))")
                    return
                }
            } else if tool.function.name == function?.name {
                if let ret = function?.Run(arguments: tool.function.arguments) {
                    messages.append(.tool(.init(content: ret, toolCallId: tool.id)))
                } else {
                    NSLog("call function not return result")
                    return
                }
            }
        }
        
        let query2 = ChatQuery(
            messages: messages,
            model: Defaults[.openAIModel]
        )
        
        var content = ""
        do {
            for try await result in openAI.chatsStream(query: query2) {
                if result.choices[0].finishReason.isNil{
                    content += result.choices[0].delta.content!
                    NSLog("content is \(content)")
                    completion(result.choices[0].delta.content!)
                }
            }
        } catch {
            NSLog("completion error \(String(describing: error))")
        }
    }
}

private func dalle3(openAI: OpenAI, arguments: String) async throws -> String {
    var content =  ""
    
    let prompt = try JSONDecoder().decode(Dalle3Prompt.self, from: arguments.data(using: .utf8)!)
    let imageQuery = ImagesQuery(
        prompt: prompt.prompt,
        model: .dall_e_3)
    let res = try await openAI.images(query: imageQuery)
    content = res.data[0].url!
    NSLog("image URL: %@", content)
    return content
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

struct ChatCompletionMessageToolCallParam: Codable, Equatable {
    public typealias ToolsType = ChatQuery.ChatCompletionToolParam.ToolsType
    
    /// The ID of the tool call.
    public let id: String
    /// The function that the model called.
    public var function: Self.FunctionCall
    /// The type of the tool. Currently, only `function` is supported.
    public let type: Self.ToolsType
    
    public init(
        id: String,
        function:  Self.FunctionCall
    ) {
        self.id = id
        self.function = function
        self.type = .function
    }
    
    public struct FunctionCall: Codable, Equatable {
        /// The arguments to call the function with, as generated by the model in JSON format. Note that the model does not always generate valid JSON, and may hallucinate parameters not defined by your function schema. Validate the arguments in your code before calling your function.
        public var arguments: String
        /// The name of the function to call.
        public let name: String
    }
}


struct Dalle3Prompt: Codable, Equatable {
    /// The ID of the tool call.
    public let prompt: String
}

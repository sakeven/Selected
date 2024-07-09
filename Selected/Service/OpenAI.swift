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

let OpenAIModels: [Model] = [.gpt4_turbo, .gpt3_5Turbo, .gpt4_o]

struct FunctionDefinition: Codable, Equatable{
    /// The name of the function to be called. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.
    public let name: String

    /// The description of what the function does.
    public let description: String
    /// The parameters the functions accepts, described as a JSON Schema object. See the guide for examples, and the JSON Schema reference for documentation about the format.
    /// Omitting parameters defines a function with an empty parameter list.
    public let parameters: String

    /// The command to execute
    public var command: [String]?
    /// In which dir to execute command.
    public var workdir: String?
    public var showResult: Bool? = true
    public var template: String?

    func Run(arguments: String, options: [String:String] = [String:String]()) -> String? {
        guard let command = self.command else {
            return nil
        }
        var args = [String](command[1...])
        args.append(arguments)

        var env = [String:String]()
        options.forEach{ (key: String, value: String) in
            env["SELECTED_OPTIONS_"+key.uppercased()] = value
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + path
        }
        return executeCommand(workdir: workdir!, command: command[0], arguments: args, withEnv: env)
    }

    func getParameters() -> FunctionParameters?{
        let p = try! JSONDecoder().decode(FunctionParameters.self, from: self.parameters.data(using: .utf8)!)
        return p
    }
}

let dalle3Def = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "Dall-E-3",
    description: "When user asks for a picture, create a prompt that dalle can use to generate the image. The prompt must be in English. Translate to English if needed. The url of the image will be returned.",
    parameters: .init(type: .object, properties:[
        "prompt": .init(type: .string, description: "the generated prompt sent to dalle3")
    ])
)


typealias ChatFunctionCall = OpenAIChatCompletionMessageToolCallParam.FunctionCall
typealias OpenAIChatCompletionMessageToolCallParam = ChatQuery.ChatCompletionMessageParam.ChatCompletionAssistantMessageParam.ChatCompletionMessageToolCallParam
typealias FunctionParameters = ChatQuery.ChatCompletionToolParam.FunctionDefinition.FunctionParameters


struct OpenAIPrompt {
    let prompt: String
    var tools: [FunctionDefinition]?
    let openAI: OpenAI
    var query: ChatQuery
    var options: [String:String]

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String:String] = [String:String]()) {
        self.prompt = prompt
        self.tools = tools
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
        self.openAI = OpenAI(configuration: configuration)
        self.options = options
        self.query = OpenAIPrompt.createQuery(functions: tools)
    }


    func chatOne(
        selectedText: String,
        completion: @escaping (_: String) -> Void) async -> Void {
            var messages = query.messages
            let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)
            messages.append(.init(role: .user, content: message)!)
            let query = ChatQuery(
                messages: messages,
                model: Defaults[.openAIModel],
                tools: query.tools
            )

            do {
                for try await result in openAI.chatsStream(query: query) {
                    if result.choices[0].finishReason.isNil && result.choices[0].delta.content != nil {
                        completion( result.choices[0].delta.content!)
                    }
                }
            } catch {
                NSLog("completion error \(String(describing: error))")
                return
            }

        }

    private static func createQuery(functions: [FunctionDefinition]?) -> ChatQuery {
        var tools: [ChatQuery.ChatCompletionToolParam]? = nil
        if let functions = functions {
            var _tools: [ChatQuery.ChatCompletionToolParam] = [.init(function: dalle3Def)]
            for fc in functions {
                let fc = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                    name: fc.name,
                    description: fc.description,
                    parameters: fc.getParameters()
                )
                _tools.append(.init(function: fc))
            }
            tools = _tools
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let localDate = dateFormatter.string(from: Date())

        let language = getCurrentAppLanguage()
        var currentLocation = ""
        if let location = LocationManager.shared.place {
            currentLocation = "I'm at \(location)"
        }
        let systemPrompt = """
                      Current time is \(localDate).
                      \(currentLocation)
                      You are a tool running on macOS called Selected. You can help user do anything.
                      The system language is \(language), you should try to reply in \(language) as much as possible, unless the user specifies to use another language, such as specifying to translate into a certain language.
                      """

        // 通过 Swift 获取当前应用的语言
        return ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!],
            model: Defaults[.openAIModel],
            tools: tools
        )
    }

    mutating func updateQuery(message: ChatQuery.ChatCompletionMessageParam) {
        var messages = query.messages
        messages.append(message)
        query = ChatQuery(
            messages: messages,
            model: Defaults[.openAIModel],
            tools: query.tools
        )
    }

    mutating func updateQuery(messages: [ChatQuery.ChatCompletionMessageParam]) {
        var _messages = query.messages
        _messages.append(contentsOf: messages)
        query = ChatQuery(
            messages: _messages,
            model: Defaults[.openAIModel],
            tools: query.tools
        )
    }

    mutating func chat(
        selectedText: String,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {
            let message = replaceOptions(content: prompt, selectedText: selectedText, options: options)
            updateQuery(message: .init(role: .user, content: message)!)

            var index = -1
            while let last = query.messages.last, last.role != .assistant {
                await chatOneRound(index: &index, completion: completion)
                if index >= 10 {
                    NSLog("call too much")
                    return
                }
            }
        }

    mutating func chatFollow(
        index: Int,
        userMessage: String,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {
            updateQuery(message: .init(role: .user, content: userMessage)!)
            var newIndex = index
            while let last = query.messages.last, last.role != .assistant {
                await chatOneRound(index: &newIndex, completion: completion)
                if newIndex-index >= 10 {
                    NSLog("call too much")
                    return
                }
            }
        }

    mutating func chatOneRound(
        index: inout Int,
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> Void {
            NSLog("index is \(index)")
            var hasTools = false
            var toolCallsDict = [Int: ChatCompletionMessageToolCallParam]()
            var hasMessage =  false
            var assistantMessage = ""
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
                        var newMessage = false
                        if !hasMessage {
                            index += 1
                            hasMessage = true
                            newMessage = true
                        }
                        let message = ResponseMessage(message: result.choices[0].delta.content!, role: "assistant", new: newMessage)
                        assistantMessage += message.message
                        completion(index, message)
                    }
                }
            } catch {
                NSLog("completion error \(String(describing: error))")
                return
            }

            if !hasTools {
                updateQuery(message: .assistant(.init(content:assistantMessage)))
                return
            }

            var toolCalls  =  [OpenAIChatCompletionMessageToolCallParam]()
            for (_, tool) in toolCallsDict {
                let function =
                try! JSONDecoder().decode(ChatFunctionCall.self, from: JSONEncoder().encode(tool.function))
                toolCalls.append(.init(id: tool.id, function: function))
            }
            updateQuery(message: .assistant(.init(content:assistantMessage, toolCalls: toolCalls)))

            let toolMessages = await callTools(index: &index, toolCallsDict: toolCallsDict, completion: completion)
            if toolMessages.isEmpty {
                return
            }
            updateQuery(messages: toolMessages)
        }

    private func callTools(
        index: inout Int,
        toolCallsDict: [Int: ChatCompletionMessageToolCallParam],
        completion: @escaping (_: Int, _: ResponseMessage) -> Void) async -> [ChatQuery.ChatCompletionMessageParam] {
            guard let fcs = tools else {
                return []
            }

            index += 1
            NSLog("tool index \(index)")

            var fcSet = [String: FunctionDefinition]()
            for fc in fcs {
                fcSet[fc.name] = fc
            }

            var messages = [ChatQuery.ChatCompletionMessageParam]()
            for (_, tool) in toolCallsDict {
                let message =  ResponseMessage(message: "Calling \(tool.function.name)...", role: "tool", new: true)

                if let f = fcSet[tool.function.name] {
                    if let template = f.template {
                        message.message =  renderTemplate(templateString: template, json: tool.function.arguments)
                        NSLog("\(message.message)")
                    }
                }
                completion(index, message)
                NSLog("\(tool.function.arguments)")
                if tool.function.name == dalle3Def.name {
                    do {
                        let url = try await dalle3(openAI: openAI, arguments: tool.function.arguments)
                        messages.append(.tool(.init(content: url, toolCallId: tool.id)))
                        let ret = "[![this is picture]("+url+")]("+url+")"
                        let message = ResponseMessage(message: ret, role: "tool",  new: true)
                        completion(index, message)
                    } catch {
                        NSLog("call function error \(String(describing: error))")
                        return []
                    }
                } else  {
                    if let f = fcSet[tool.function.name] {
                        if let ret = f.Run(arguments: tool.function.arguments, options: options) {
                            let message = ResponseMessage(message: ret, role: "tool",  new: true)
                            if let show = f.showResult, !show {
                                if f.template != nil {
                                    message.message = ""
                                    message.new = false
                                } else {
                                    message.message = "\(f.name) called"
                                }
                            }
                            completion(index, message)
                            messages.append(.tool(.init(content: ret, toolCallId: tool.id)))
                        } else {
                            NSLog("call function not return result")
                            return []
                        }
                    }
                }
            }
            return messages
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

let OpenAITrans2Chinese = OpenAIPrompt(prompt:"你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则： 请直接回复翻译后的内容。内容为：{selected.text}")

let OpenAITrans2English = OpenAIPrompt(prompt:"You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}")

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

func openAITTS2(_ text: String) async -> Data? {
    clearExpiredVoiceData()
    if let data = voiceDataCache[text.hash] {
        NSLog("cached tts")
        return data.data
    }

    let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey] , host: Defaults[.openAIAPIHost] , timeoutInterval: 60.0)
    let openAI = OpenAI(configuration: configuration)
    let query = AudioSpeechQuery(model: .tts_1, input: text, voice: Defaults[.openAIVoice], responseFormat: .mp3, speed: 1.0)

    do {
        let result = try await openAI.audioCreateSpeech(query: query)
        voiceDataCache[text.hash] = VoiceData(data: result.audio , lastAccessTime: Date())
        return result.audio
    } catch {
        NSLog("audioCreateSpeech \(error)")
        return nil
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


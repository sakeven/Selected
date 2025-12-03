//
//  AI.swift
//  Selected
//
//  Created by sake on 2024/3/10.
//

import Defaults
import SwiftUI
import OpenAI

public struct ChatContext {
    let text: String
    let webPageURL: String
    let bundleID: String
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

struct Translation {
    let toLanguage: String

    func translate(content: String, completion: @escaping (_: String) -> Void) async -> Void {
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

    private func contentTrans2Chinese(content: String, completion: @escaping (_: String) -> Void) async -> Void{
        var prompt = "你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}"
        if isWord(str: content) {
            prompt = "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}"
        }
        guard let translator = TranslateService(prompt: prompt) else {
            completion("no model \(Defaults[.aiService])")
            return
        }
        do {
            let stream = translator.chatOnce(selectedText: content)
            for try await event in stream {
                if case let .textDelta(txt) = event{
                    completion(txt)
                }
            }
        } catch {
            print("contentTrans2Chinese error \(error)")
        }
    }


    private func contentTrans2English(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        let prompt = "You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}"
        guard let translator = TranslateService(prompt: prompt) else {
            completion("no model \(Defaults[.aiService])")
            return
        }
        do {
            let stream = translator.chatOnce(selectedText: content)
            for try await event in stream {
                if case let .textDelta(txt) = event{
                    completion(txt)
                }
            }
        } catch {
            print("catch \(error)")
        }
    }


    struct TranslateService{
        var chatService: AIProvider

        init?(prompt: String){
            switch Defaults[.aiService] {
                case "OpenAI":
                    chatService = OpenAIProvider(prompt: prompt, model: Defaults[.openAITranslationModel], reasoning: false)
                case "Claude":
                    chatService = ClaudeAIProvider(prompt: prompt, model: .claude_haiku_4_5)
                default:
                    return nil
            }
        }

        func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
            chatService.chatOnce(selectedText: selectedText)
        }
    }
}

protocol AIProvider {
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chatFollow(userMessage: String) -> AsyncThrowingStream<AIStreamEvent, Error>
}


struct ChatService: AIProvider{
    var chatService: AIProvider

    init?(prompt: String, tools: [FunctionDefinition]? = nil, options: [String:String], reasoning: Bool = true){
        switch Defaults[.aiService] {
            case "OpenAI":
                chatService = OpenAIProvider(prompt: prompt, tools: tools, options: options, reasoning: reasoning)
            case "Claude":
                chatService = ClaudeAIProvider(prompt: prompt, tools: tools, options: options, reasoning: reasoning)
            default:
                return nil
        }
    }


    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        chatService.chat(ctx: ctx)
    }

    func chatFollow(userMessage: String) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        chatService.chatFollow(userMessage: userMessage)
    }

    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        chatService.chatOnce(selectedText: selectedText)
    }
}


public class ResponseMessage: ObservableObject, Identifiable, Equatable{
    public static func == (lhs: ResponseMessage, rhs: ResponseMessage) -> Bool {
        lhs.id == rhs.id
    }

    public enum Status: String {
        case initial, updating, finished, failure
    }

    public enum Role: String {
        case assistant, user, system
    }

    public var id = UUID()

    @Published var summary: String
    @Published var message: String
    @Published var role: Role
    @Published var status: Status
    @Published var tools: [String: AIToolCall]

    // 给 View 用的、有序的数组视图
    var items: [(key: String, value: AIToolCall)] {
        tools.sorted { $0.key < $1.key }   // 按 key 排序
    }

    var new: Bool = false // new start of message

    init(id: UUID = UUID(), message: String, role: Role, new: Bool = false, status: Status = .initial) {
        self.id = id
        self.message = message
        self.role = role
        self.new = new
        self.status = status
        self.summary = ""
        self.tools = [String: AIToolCall]()
    }
}


func systemPrompt() -> String{
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.current
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let localDate = dateFormatter.string(from: Date())

    let language = getCurrentAppLanguage()
    var currentLocation = ""
    if let location = LocationManager.shared.place {
        currentLocation = "I'm at \(location)"
    }
    return """
                      Current time is \(localDate).
                      \(currentLocation)
                      You are a tool running on macOS called Selected. You can help user do anything.
                      The system language is \(language), you should try to reply in \(language) as much as possible, unless the user specifies to use another language, such as specifying to translate into a certain language.
                      """
}


let svgToolOpenAIDef = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "svg_dispaly",
    description: "When user requests you to create an SVG, you can use this tool to display the SVG.",
    parameters: .init(
        fields: [
            .type( .object),
            .properties(
                [
                    "raw": .init(
                        fields: [
                            .type(.string), .description("SVG content")
                        ])
                ])
        ])
)



struct SVGData: Codable, Equatable {
    public let raw: String
}

// 输入为 svg 的原始数据，要求保存到一个临时文件里，然后通过默认浏览器打开这个文件。
func openSVGInBrowser(svgData: String) -> Bool {
    do {
        let data = try JSONDecoder().decode(SVGData.self, from: svgData.data(using: .utf8)!)

        // 创建临时文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("temp_svg_\(UUID().uuidString).svg")

        // 将 SVG 数据写入临时文件
        try data.raw.write(to: tempFile, atomically: true, encoding: .utf8)

        // 使用默认浏览器打开文件
        DispatchQueue.global().async {
            NSWorkspace.shared.open(tempFile)
        }
        return true
    } catch {
        print("打开 SVG 文件时发生错误: \(error.localizedDescription)")
        return false
    }
}

let MAX_CHAT_ROUNDS = 20

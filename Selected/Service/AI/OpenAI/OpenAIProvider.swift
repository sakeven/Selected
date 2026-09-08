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


final class MiddleWare: OpenAIMiddleware {
    func intercept(response: URLResponse?, request: URLRequest, data: Data?) -> (response: URLResponse?, data: Data?) {
        if let data = data {
            print(String(data: data, encoding: .utf8) ?? "no data")
        } else {
            AppLogger.ai.debug("no data")
        }
        return (response, data)
    }
}

class OpenAIProvider: AIProvider{
    private let prompt: String
    private var tools: [FunctionDefinition]?
    private let openAI: OpenAI
    private var responseQuery: CreateModelResponseQuery
    private var options: [String: String]

    // 初始化时传入 prompt、工具列表和其他选项
    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String: String] = [:], reasoning: Bool = true) {
        self.prompt = prompt
        self.tools = tools
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: APIKeyStore.shared.value(for: .openAI), host: host, timeoutInterval: 60.0, parsingOptions: .relaxed)
        self.openAI = OpenAI(configuration: configuration, middlewares: [MiddleWare()])
        self.options = options
        self.responseQuery = OpenAIProvider.createResponseQuery(functions: tools, model: Defaults[.openAIModel], thinking: reasoning)
    }

    // 初始化时直接传入 prompt 和模型
    init(prompt: String, model: OpenAIModel, reasoning: Bool = true) {
        self.prompt = prompt
        self.tools = nil
        var host = "api.openai.com"
        if Defaults[.openAIAPIHost] != "" {
            host = Defaults[.openAIAPIHost]
        }
        let configuration = OpenAI.Configuration(token: APIKeyStore.shared.value(for: .openAI), host: host, timeoutInterval: 60.0)
        self.openAI = OpenAI(configuration: configuration)
        self.options = [:]
        self.responseQuery = OpenAIProvider.createResponseQuery(functions: tools, model: model, thinking: reasoning)
    }

    static func messageInput(_ message: UserMessage) -> CreateModelResponseQuery.Input {
        var inputItems = [InputContent]()
        inputItems.append(.inputText(.init(_type: .inputText, text: message.text)))
        for image in message.images {
            let mimeType = image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
            inputItems.append(.inputImage(.init(_type: .inputImage, imageUrl: "data:\(mimeType);base64,\(image.base64EncodedString())", detail: .auto)))
        }
        for file in message.files {
            inputItems.append(.inputFile(.init(_type: .inputFile, filename: file.filename, fileData: "data:\(file.mimeType);base64,\(file.data.base64EncodedString())")))
        }
        return .inputItemList([
            .inputMessage(.init(role: .user, content: .inputItemContentList(inputItems)))
        ])
    }

    /// 单轮对话，适合简单返回结果（流式返回）
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let messageContent = replaceOptions(content: prompt, selectedText: selectedText, options: options)
        responseQuery = responseQuery.continuing(with: .textInput(messageContent), previousResponseID: responseQuery.previousResponseId)
        let stream: AsyncThrowingStream<ResponseStreamEvent, Error> = openAI.responses.createResponseStreaming(query: responseQuery)
        let response = OpenAIResponseState()
        return AsyncThrowingStream {
            continuation in
            Task {
                do {
                    for try await event in stream {
                        try response.handleResponseStreamEvent(event, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 发起对话，会进行多轮聊天直至收到 assistant 的回答
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> {
        chatFollow(userMessage: ctx.message(prompt: prompt, options: options))
    }

    private let maxToolLoops = 8

    /// 处理用户后续的消息
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error>  {
        responseQuery = responseQuery.continuing(with: Self.messageInput(userMessage), previousResponseID: responseQuery.previousResponseId)
        return conversationStream(maxToolLoops: maxToolLoops) { continuation in
            try await self.chatOneRound(continuation: continuation)
        }
    }

    /// 单轮聊天流程，包括流式处理和工具调用
    private func chatOneRound(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> Bool  {
        do {
            let openAIStream: AsyncThrowingStream<ResponseStreamEvent, Error> =  openAI.responses.createResponseStreaming(query: responseQuery)

            let response = OpenAIResponseState()
            for try await event in openAIStream {
                do {
                    try response.handleResponseStreamEvent(event, continuation: continuation)
                } catch {
                    AppLogger.ai.debug("handleResponseStreamEvent \(error)")
                    throw error
                }
            }

            if response.hasToolsCalled {
                if let input = try await callTools(toolCallsDict: response.toolCallsDict, continuation: continuation) {
                    responseQuery = responseQuery.continuing(with: input, previousResponseID: response.lastOpenAIResponseId!)
                    return true
                }
            } else {
                responseQuery = responseQuery.continuing(with: responseQuery.input, previousResponseID: response.lastOpenAIResponseId!)
            }
        }
        return false
    }

    // 内部方法：调用工具函数
    private func callTools(toolCallsDict: [String: FunctionCallParam], continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> CreateModelResponseQuery.Input? {
        guard let functions = tools else { return nil }

        // 构建工具映射
        var functionMap = [String: FunctionDefinition]()
        for function in functions {
            functionMap[function.name] = function
        }


        var input = [InputItem]()
        for (callId, tool) in toolCallsDict {
            // 如果工具定义中有模板，则渲染后更新消息
            var toolMessage = ""
            let functionDef = functionMap[tool.name]
            if let funcDef = functionDef,
               let template = funcDef.template {
                toolMessage = renderTemplate(templateString: template, json: tool.arguments)
                AppLogger.ai.debug("\(toolMessage)")
            }
            continuation.yield(.toolCallStarted(.init(
                id: tool.id,
                name: tool.name,
                message: toolMessage,
                arguments: tool.arguments,
                command: functionDef?.commandLine,
                workdir: functionDef?.workdir,
                sourceLinks: []
            )))

            // 根据工具名称调用不同的逻辑
            if tool.name == svgToolOpenAIDef.name {
                _ = openSVGInBrowser(svgData: tool.arguments)

                let item = Components.Schemas.Item.FunctionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output:  .case1("display svg successfully")))
                input.append(.item(item))

                let message = ToolCallResult(
                    id: tool.id,
                    name: tool.name,
                    ret: NSLocalizedString("display_svg", comment: ""),
                    arguments: tool.arguments,
                    command: nil,
                    workdir: nil,
                    sourceLinks: []
                )
                continuation.yield(.toolCallFinished(message))

            } else {
                if let funcDef = functionMap[tool.name] {
                    AppLogger.ai.debug("call: \(tool.arguments)")
                    if let ret = try funcDef.Run(arguments: tool.arguments, options: options) {
                        let statusMessage = (funcDef.showResult ?? true)
                        ? ret
                        : String(format: NSLocalizedString("called_tool", comment: "tool message"), funcDef.name)
                        let message = ToolCallResult(
                            id: tool.id,
                            name: tool.name,
                            ret: statusMessage,
                            arguments: tool.arguments,
                            command: funcDef.commandLine,
                            workdir: funcDef.workdir,
                            sourceLinks: []
                        )
                        continuation.yield(.toolCallFinished(message))
                        let item = Components.Schemas.Item.FunctionCallOutputItemParam(.init(callId: callId, _type: .functionCallOutput, output: .case1(ret)))
                        input.append(.item(item))
                    }
                }
            }
        }
        return CreateModelResponseQuery.Input.inputItemList(input)
    }

    private static func createResponseQuery(functions: [FunctionDefinition]?, model: OpenAIModel, thinking: Bool) -> CreateModelResponseQuery {
        var tools: [Tool]? = nil
        if let functions = functions {
            var toolList: [Tool] = [
                .functionTool(.init(name: svgToolOpenAIDef.name,
                                    description: svgToolOpenAIDef.description,
                                    parameters: svgToolOpenAIDef.parameters!, strict: false))
            ]
            for fc in functions {
                let fcConverted = Tool.functionTool(
                    .init(
                        name: fc.name,
                        description: fc.description,
                        parameters: fc.getParameters()!,
                        strict: false,
                    )
                )
                toolList.append(fcConverted)
            }
            tools = toolList
        }

        let reasoning = model.reasoningConfiguration(
            preferred: Defaults[.openAIModelReasoningEffort],
            thinking: thinking
        )
        if reasoning != nil, var toolList = tools {
            toolList.append(.webSearchTool(.init(_type: .webSearch)))
            tools = toolList
        }


        return CreateModelResponseQuery(
            input: .textInput(""),
            model: model,
            instructions: systemPrompt(),
            reasoning:  reasoning,
            stream: true,
            text: .text,
            tools: tools,
        )
    }
}

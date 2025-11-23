////
////  ClaudeProvider.swift
////  Selected
////
////  Created by sake on 24/11/25.
////
//
//
//import SwiftAnthropic
//
//final class ClaudeProvider {
//    let kind: AIProviderKind = .anthropic
//    let displayName: String = "Claude"
//    
//    private let service: AnthropicServiceProtocol
//    private let model: MessageParameter.Model
//    
//    init(apiKey: String, model: MessageParameter.Model) {
//        self.service = AnthropicServiceFactory.service(apiKey: apiKey)
//        self.model = model
//    }
//    
//    func stream(
//        messages: [AIMessage],
//        tools: [AIToolDefinition],
//        options: AIRequestOptions
//    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
//        let mappedMessages = mapMessages(messages)
//        let mappedTools = mapTools(tools)
//        
//        var thinking: MessageParameter.Thinking?
//        if let budget = options.reasoningBudgetTokens {
//            thinking = .init(type: .enabled, budgetTokens: budget)   // Extended Thinking:contentReference[oaicite:7]{index=7}
//        }
//        
//        let params = MessageParameter(
//            model: model,
//            messages: mappedMessages,
//            maxTokens: options.maxTokens ?? 1024,
//            system: nil,
//            tools: mappedTools.isEmpty ? nil : mappedTools,
//            thinking: thinking
//        )
//        
//        return AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let stream = try await service.streamMessage(params)
//                    var final = AIMessage(role: .assistant)
//                    var toolCallBuffers: [String: AIToolCall] = [:]
//                    
//                    for try await event in stream {
//                        // event: MessageStreamResponse
//                        guard let eventType = MessageStreamResponse.StreamEvent(rawValue: event.type) else { continue }
//                        
//                        switch eventType {
//                        case .contentBlockStart:
//                            if let block = event.contentBlock, block.type == "tool_use", let tool = block.toolUse {
//                                let call = AIToolCall(id: tool.id, name: tool.name, argumentsJSON: "")
//                                toolCallBuffers[tool.id] = call
//                                continuation.yield(.toolCallStarted(call))
//                            }
//                            
//                        case .contentBlockDelta:
//                            if let delta = event.delta {
//                                // 文本增量
//                                if let text = delta.text, !text.isEmpty {
//                                    // reasoning：Claude 3.7 thinking 模式目前是一个单独的 content block type= "thinking"
//                                    // 实际识别方式要看官方文档，这里简单示意：
//                                    let isReasoning = (delta.type == "thinking")
//                                    if isReasoning {
//                                        final.reasoning = (final.reasoning ?? "") + text
//                                    } else {
//                                        final.text += text
//                                    }
//                                    continuation.yield(.textDelta(text, isReasoning: isReasoning))
//                                }
//                                
//                                // 工具参数 partialJson
//                                if let partial = delta.partialJson, !partial.isEmpty {
//                                    // 这里 Anthropic 用 index 区分 block，简化处理：假设当前 index 对应唯一一个 tool_use
//                                    if let idx = event.index {
//                                        // 实际上你可以维护 index -> toolId 映射
//                                        let toolId = "tool-\(idx)"
//                                        if toolCallBuffers[toolId] == nil {
//                                            toolCallBuffers[toolId] = .init(id: toolId, name: "unknown", argumentsJSON: "")
//                                        }
//                                        toolCallBuffers[toolId]?.argumentsJSON += partial
//                                        continuation.yield(.toolCallArgumentsDelta(id: toolId, delta: partial))
//                                    }
//                                }
//                            }
//                            
//                        case .contentBlockStop:
//                            if let block = event.contentBlock, block.type == "tool_use", let tool = block.toolUse {
//                                if var call = toolCallBuffers[tool.id] {
//                                    // argumentsJSON 已经在 partialJson 阶段累积完了
//                                    call.name = tool.name
//                                    toolCallBuffers[tool.id] = call
//                                    continuation.yield(.toolCallFinished(call))
//                                }
//                            }
//                            
//                        case .messageDelta:
//                            if let delta = event.delta {
//                                if let stopReason = delta.stopReason, stopReason != "" {
//                                    final.toolCalls = Array(toolCallBuffers.values)
//                                    continuation.yield(.done(finalMessage: final))
//                                    continuation.finish()
//                                    return
//                                }
//                            }
//                            
//                        case .messageStart, .messageStop:
//                            // 这些事件你按需处理，这里忽略
//                            break
//                        }
//                    }
//                    
//                    final.toolCalls = Array(toolCallBuffers.values)
//                    continuation.yield(.done(finalMessage: final))
//                    continuation.finish()
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
//    }
//}
//
//private extension ClaudeProvider {
//    func mapMessages(_ messages: [AIMessage]) -> [MessageParameter.Message] {
//        messages.map { msg in
//            switch msg.role {
//            case .system:
//                return .init(role: .system, content: .text(msg.text))
//            case .user:
//                return .init(role: .user, content: .text(msg.text))
//            case .assistant:
//                // 这里只回放最终文本，tool_use 的历史按需补
//                return .init(role: .assistant, content: .text(msg.text))
//            case .toolResult:
//                // Anthropic 没有单独 tool role，一般是 assistant 内容中的 tool_result 块
//                return .init(role: .assistant, content: .text(msg.text))
//            case .reasoning:
//                // reasoning 历史一般不用重放
//                return .init(role: .assistant, content: .text(msg.text))
//            }
//        }
//    }
//    
//    func mapTools(_ tools: [AIToolDefinition]) -> [MessageParameter.Tool] {
//        tools.map { t in
//            .function(
//                name: t.name,
//                description: t.description,
//                inputSchema: .init(
//                    type: .object,
//                    // 这里简单把原始 schema 挂进去，你可以更精细地映射
//                    properties: [:],
//                    required: []
//                )
//            )
//        }
//    }
//}

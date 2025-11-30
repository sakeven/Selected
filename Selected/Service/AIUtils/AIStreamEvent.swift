//
//  AIStreamEvent.swift
//  Selected
//
//  Created by sake on 24/11/25.
//

import Foundation

enum AIRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case toolResult     // 函数执行结果
    case reasoning      // 专门展示推理内容时可以用（可选）
}

struct AIMessage: Identifiable, Sendable {
    let id: UUID
    let role: AIRole
    var text: String
    /// 工具调用结构（assistant 消息里可能会有）
    var toolCalls: [AIToolCall]
    /// reasoning 模型的“思考过程”
    var reasoning: String?

    init(
        id: UUID = UUID(),
        role: AIRole,
        text: String = "",
        toolCalls: [AIToolCall] = [],
        reasoning: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
        self.reasoning = reasoning
    }
}

enum AIStreamEvent {
    case begin(String)                 // 普通回答的增量

    case textDelta(String)                 // 普通回答的增量
    case textDone(String)                 // 普通回答的全量内容

    case reasoningDelta(String)           // 推理模型的「推理内容」增量（展示用）
    case reasoningDone(String)              // 推理模型的「推理内容」全量

    case toolCallStarted(ToolCallStart)      // 第一次出现这个 tool_call
    case toolCallFinished(ToolCallResult)     // 结束（可选）

    case error(String)
    
    case done                             // 整个响应结束
}

struct AIToolDefinition {
    let name: String
    let description: String
    let parametersJSONSchema: [String: Any]  // or some JSONSchema wrapper
}

struct AIToolCall: Identifiable {
    let id = UUID()

    let name: String
    let ret: String
    let status: AIToolCallStatus
}

enum AIToolCallStatus {
    case calling
    case success
    case failure
}

struct ToolCallResult {
    let name: String
    let ret: String
}

struct ToolCallStart {
    let name: String
    let message: String
}

struct AIToolCallDelta {
    let id: String
    let argumentsDelta: String
}

enum AIModel {
    case openAI(String)
    case anthropic(String)
}

enum AIProviderKind: String, Sendable {
    case openAI
    case anthropic
}

protocol AIProvider {
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chatFollow(userMessage: String) -> AsyncThrowingStream<AIStreamEvent, Error>
}

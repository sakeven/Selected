//
//  AIStreamEvent.swift
//  Selected
//
//  Created by sake on 24/11/25.
//

import Foundation

enum AIStreamEvent {
    case begin(String)                 // 普通回答的增量

    case textDelta(String)                 // 普通回答的增量
    case textDone(String)                 // 普通回答的全量内容

    case reasoningDelta(String)           // 推理模型的「推理内容」增量（展示用）
    case reasoningDone(String)              // 推理模型的「推理内容」全量

    case toolCallStarted(ToolCallStart)      // 第一次出现这个 tool_call
    case toolCallFinished(ToolCallResult)     // 结束（可选）
    case toolCallUpdated(ToolCallUpdate)

    case error(String)
    
    case done                             // 整个响应结束
}

struct AIToolCall: Identifiable {
    let id = UUID()

    let name: String
    let ret: String
    let status: AIToolCallStatus
    let arguments: String?
    let command: String?
    let workdir: String?
    let sourceLinks: [AIToolSourceLink]
}

enum AIToolCallStatus {
    case calling
    case success
    case failure
}

struct AIToolSourceLink: Identifiable, Hashable {
    let title: String
    let url: String

    var id: String { "\(title)|\(url)" }
}

struct ToolCallResult {
    let id: String
    let name: String
    let ret: String
    let arguments: String?
    let command: String?
    let workdir: String?
    let sourceLinks: [AIToolSourceLink]
}

struct ToolCallStart {
    let id: String
    let name: String
    let message: String
    let arguments: String?
    let command: String?
    let workdir: String?
    let sourceLinks: [AIToolSourceLink]
}

struct ToolCallUpdate {
    let id: String
    let sourceLinks: [AIToolSourceLink]
}

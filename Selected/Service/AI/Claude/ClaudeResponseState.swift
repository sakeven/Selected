import Foundation
import SwiftAnthropic

struct ClaudeResponseState {
    private var assistantMessage = ""
    private var thinking = ""
    private var toolParameters = ""
    private var signature = ""
    private(set) var toolUseList = [ClaudeToolUse]()
    private var lastToolUseBlockIndex = -1

    mutating func consume(_ result: MessageStreamResponse, continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) throws {
        let content = result.delta?.text ?? ""
        if !content.isEmpty {
            continuation.yield(.textDelta(content))
            assistantMessage += content
        }

        let deltaThinking = result.delta?.thinking ?? ""
        if !deltaThinking.isEmpty {
            thinking += deltaThinking
            continuation.yield(.reasoningDelta(deltaThinking))
        }
        signature += result.delta?.signature ?? ""

        switch result.streamEvent {
            case .contentBlockStart:
                if let toolUse = result.contentBlock?.toolUse {
                    toolUseList.append(ClaudeToolUse(id: toolUse.id, name: toolUse.name, input: ""))
                    toolParameters = ""
                    lastToolUseBlockIndex = result.index!
                }
            case .contentBlockDelta:
                if lastToolUseBlockIndex == result.index! {
                    toolParameters += result.delta?.partialJson ?? ""
                }
            case .contentBlockStop:
                if lastToolUseBlockIndex == result.index! {
                    var toolUse = toolUseList.last!
                    toolUse.input = try JSONFormatter.prettify(toolParameters)
                    toolUseList[toolUseList.count - 1] = toolUse
                }
            default:
                break
        }
    }

    func finish(continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation) throws -> MessageParameter.Message {
        continuation.yield(.reasoningDone(thinking))

        if !assistantMessage.isEmpty {
            continuation.yield(.textDone(assistantMessage))
        }

        var contents = [MessageParameter.Message.Content.ContentObject]()
        if !thinking.isEmpty {
            contents.append(.thinking(thinking, signature))
        }
        contents.append(.text(assistantMessage))


        // 将工具调用封装到查询记录中
        for tool in toolUseList {
            let input = try JSONDecoder().decode(SwiftAnthropic.MessageResponse.Content.Input.self, from: tool.input.data(using: .utf8)!)
            contents.append(.toolUse(tool.id, tool.name, input))
        }
        return .init(role: .assistant, content: .list(contents))
    }
}

//
//  MessageViewModel.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [ResponseMessage] = []
    var chatService: AIProvider

    init(chatService: AIProvider) {
        self.chatService = chatService
        self.messages.append(ResponseMessage(message: NSLocalizedString("waiting", comment: "system info"), role: .system))
    }

    func submit(message: String) async {
        var idx = self.messages.count-1
        let lastOpenAIResponseId = self.messages[idx].lastResponseId
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.messages.append(ResponseMessage(message: message, role: .user, status: .finished))
                }
            }
        }
        let stream = chatService.chatFollow(userMessage: message, lastResponseId: lastOpenAIResponseId)

        self.messages.append(ResponseMessage(message: "", role: .assistant, status: .initial))
        idx = self.messages.count-1

        do {
            for try await event in stream {
                switch event {
                    case .begin(let lastOpenAIResponseId):
                        self.messages[idx].lastResponseId = lastOpenAIResponseId
                        self.messages[idx].status = .updating
                        break
                    case .textDelta(let txt):
                        self.messages[idx].message += txt
                    case .textDone(let txt):
                        self.messages[idx].message = txt
                        self.messages[idx].status = .finished
                    case .toolCallStarted(let toolName):
                        self.messages[idx].tools[toolName] = AIToolCall(name: toolName, ret: "", status: .calling)
                    case .toolCallFinished(let result):
                        self.messages[idx].tools[result.name] = AIToolCall(name: result.name, ret: result.ret, status: .success)
                    case .reasoningDelta(let reasoningDelta):
                        self.messages[idx].summary += reasoningDelta
                    case .reasoningDone(_):
                        // only part of reasoning context done.
                        self.messages[idx].summary +=  "\n\n"
                    case .error(let err):
                        self.messages[idx].role = .system
                        self.messages[idx].status = .failure
                        self.messages[idx].message = err
                    default:
                        break
                }
            }
        } catch {
        }
    }

    // 开启第一条对话
    func fetchMessages(ctx: ChatContext) async -> Void{
        let stream = chatService.chat(ctx: ctx)

        let idx = self.messages.count-1
        do {
            for try await event in stream {
                switch event {
                    case .begin(let lastResponseId):
                        self.messages[idx].role = .assistant
                        self.messages[idx].message = ""
                        self.messages[idx].status = .updating
                        self.messages[idx].lastResponseId = lastResponseId
                        break
                    case .textDelta(let txt):
                        self.messages[idx].message += txt
                    case .textDone(let txt):
                        self.messages[idx].message = txt
                        self.messages[idx].status = .finished
                    case .toolCallStarted(let toolName):
                        self.messages[idx].tools[toolName] = AIToolCall(name: toolName, ret: "", status: .calling)
                    case .toolCallFinished(let result):
                        self.messages[idx].tools[result.name] = AIToolCall(name: result.name, ret: result.ret, status: .success)
                    case .error(let err):
                        self.messages[idx].role = .system
                        self.messages[idx].message = err
                    case .reasoningDelta(let reasoningDelta):
                        self.messages[idx].summary += reasoningDelta
                    case .reasoningDone(_):
                        // only part of reasoning context done.
                        self.messages[idx].summary +=  "\n\n"
                    default:
                        break
                }
            }
        } catch {
        }
    }
}

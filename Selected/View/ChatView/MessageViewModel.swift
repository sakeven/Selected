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
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.messages.append(ResponseMessage(message: message, role: .user, status: .finished))
                }
            }
        }
        let stream = chatService.chatFollow(userMessage: message)

        self.messages.append(ResponseMessage(message: "", role: .assistant, status: .initial))
        let idx = self.messages.count-1
        do {
            for try await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                    case .begin(_):
                        self.messages[idx].status = .updating
                        break
                    case .textDelta(let txt):
                        self.messages[idx].message += txt
                    case .textDone(let txt):
                        self.messages[idx].message = txt
                        self.messages[idx].status = .finished
                    case .toolCallStarted(let toolStartStatus):
                        self.messages[idx].tools[toolStartStatus.name] = AIToolCall(name: toolStartStatus.name, ret: toolStartStatus.message, status: .calling)
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
            self.messages[idx].role = .system
            self.messages[idx].status = .failure
            self.messages[idx].message = error.localizedDescription
        }
    }

    // 开启第一条对话
    func fetchMessages(ctx: ChatContext) async -> Void{
        let stream = chatService.chat(ctx: ctx)

        let idx = self.messages.count-1
        do {
            for try await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                    case .begin(_):
                        self.messages[idx].role = .assistant
                        self.messages[idx].message = ""
                        self.messages[idx].status = .updating
                        break
                    case .textDelta(let txt):
                        self.messages[idx].message += txt
                    case .textDone(let txt):
                        self.messages[idx].message = txt
                        self.messages[idx].status = .finished
                    case .toolCallStarted(let toolStartStatus):
                        self.messages[idx].tools[toolStartStatus.name] = AIToolCall(name: toolStartStatus.name, ret: toolStartStatus.message, status: .calling)
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
            if self.messages[idx].role == .assistant {
                self.messages[idx].status = .finished
            }
        } catch {
            self.messages[idx].role = .system
            self.messages[idx].status = .failure
            self.messages[idx].message = error.localizedDescription
        }
    }
}

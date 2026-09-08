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
    @Published var inProgress: Bool
    var chatService: AIProvider

    init(chatService: AIProvider) {
        self.chatService = chatService
        self.inProgress = false
        self.messages.append(ResponseMessage(message: NSLocalizedString("waiting", comment: "system info"), role: .system))
    }

    func submit(message: UserMessage) async {
        self.inProgress = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.messages.append(ResponseMessage(message: message.text, images: message.images, files: message.files, role: .user, status: .finished))
                }
            }
        }
        let stream = chatService.chatFollow(userMessage: message)

        self.messages.append(ResponseMessage(message: "", role: .assistant, status: .initial))
        let idx = self.messages.count-1
        defer {
            if self.messages[idx].status == .initial || self.messages[idx].status == .updating {
                self.messages[idx].status = .finished
            }
            self.inProgress = false
        }
        do {
            for try await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                    case .begin(_):
                        self.messages[idx].status = .updating
                        break
                    case .error(let err):
                        self.messages[idx].role = .system
                        self.messages[idx].status = .failure
                        self.messages[idx].message = err
                    default:
                        self.messages[idx].applyContentEvent(event)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            self.messages[idx].role = .system
            self.messages[idx].status = .failure
            self.messages[idx].message = error.localizedDescription
        }
    }

    var usesOpenAIFileInputs: Bool {
        let provider = (chatService as? ChatService)?.chatService ?? chatService
        return provider is OpenAIProvider
    }

    // 开启第一条对话
    func fetchMessages(ctx: ChatContext) async -> Void{
        self.inProgress = true
        let stream = chatService.chat(ctx: ctx)

        let idx = self.messages.count-1
        defer { self.inProgress = false }
        do {
            for try await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                    case .begin(_):
                        self.messages[idx].role = .assistant
                        self.messages[idx].message = ""
                        self.messages[idx].status = .updating
                        break
                    case .error(let err):
                        self.messages[idx].status = .failure
                        self.messages[idx].role = .system
                        self.messages[idx].message = err
                    default:
                        self.messages[idx].applyContentEvent(event)
                }
            }
            if self.messages[idx].role == .assistant {
                self.messages[idx].status = .finished
            }
        } catch {
            guard !Task.isCancelled else {
                self.messages[idx].status = .finished
                return
            }
            self.messages[idx].role = .system
            self.messages[idx].status = .failure
            self.messages[idx].message = error.localizedDescription
        }
    }

}

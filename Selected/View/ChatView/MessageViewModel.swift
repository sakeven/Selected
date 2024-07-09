//
//  MessageViewModel.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation

class MessageViewModel: ObservableObject {
    @Published var messages: [ResponseMessage] = []
    var chatService: AIChatService

    init(chatService: AIChatService) {
        self.chatService = chatService
        self.messages.append(ResponseMessage(message: "waiting", role: "none"))
    }


    func submit(message: String) async -> Void {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.messages.append(ResponseMessage(message: message, role: "user"))
                }
            }
        }
        await chatService.chatFollow(index: messages.count-1, userMessage: message){ [weak self]  index, message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.messages.count < index+1 {
                    self.messages.append(ResponseMessage(message: "", role:  message.role))
                }

                if message.role != self.messages[index].role {
                    self.messages[index].role = message.role
                }

                if message.new {
                    self.messages[index].message = message.message
                } else {
                    self.messages[index].message += message.message
                }
            }
        }
    }

    func fetchMessages(ctx: ChatContext) async -> Void{
        await chatService.chat(ctx: ctx) { [weak self]  index, message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.messages.count < index+1 {
                    self.messages.append(ResponseMessage(message: "", role:  message.role))
                }

                if message.role != self.messages[index].role {
                    self.messages[index].role = message.role
                }

                if message.new {
                    self.messages[index].message = message.message
                } else {
                    self.messages[index].message += message.message
                }
            }
        }
    }
}

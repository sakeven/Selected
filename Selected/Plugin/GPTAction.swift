//
//  GPTAction.swift
//  Selected
//
//  Created by sake on 2024/6/2.
//

import Foundation

class GptAction: Decodable{
    var prompt: String
    var tools: [FunctionDefinition]?

    init(prompt: String) {
        self.prompt = prompt
    }
    
    func generate(pluginInfo: PluginInfo,  generic: GenericAction) -> PerformAction {
        if generic.after == kAfterPaste  {
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    await ChatService(prompt: self.prompt).chat(content: ctx.Text, options: pluginInfo.getOptionsValue()) { _, ret in
                        pasteText(ret.message)
                    }
                })
        } else {
            var chatService: AIChatService = ChatService(prompt: prompt)
            if let tools = tools {
                chatService = OpenAIService(prompt: prompt, tools: tools)
            }
            
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    WindowManager.shared.createChatWindow(chatService: chatService, withText: ctx.Text, options: pluginInfo.getOptionsValue())
                })
        }
    }
}

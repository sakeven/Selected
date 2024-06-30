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
                    await ChatService(prompt: self.prompt, options: pluginInfo.getOptionsValue())!.chat(content: ctx.Text) { _, ret in
                        pasteText(ret.message)
                    }
                })
        } else {
            var chatService: AIChatService = ChatService(prompt: prompt, options: pluginInfo.getOptionsValue())!
            if let tools = tools {
                chatService = OpenAIService(prompt: prompt, tools: tools, options: pluginInfo.getOptionsValue())
            }
            
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    WindowManager.shared.createChatWindow(chatService: chatService, withText: ctx.Text)
                })
        }
    }
}

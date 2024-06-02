//
//  GPTAction.swift
//  Selected
//
//  Created by sake on 2024/6/2.
//

import Foundation

class GptAction: Decodable{
    var prompt: String
    var tool: FunctionDefinition?
    
    init(prompt: String) {
        self.prompt = prompt
    }
    
    func generate(pluginInfo: PluginInfo,  generic: GenericAction) -> PerformAction {
        if generic.after == kAfterPaste  {
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    await ChatService(prompt: self.prompt).chat(content: ctx.Text, options: pluginInfo.getOptionsValue()) { ret in
                        pasteText(ret)
                    }
                })
        } else {
            var chatService: AIChatService = ChatService(prompt: prompt)
            if let tool = tool {
                chatService = OpenAIService(prompt: prompt, functionDef: tool)
            }
            
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    WindowManager.shared.createChatWindow(chatService: chatService, withText: ctx.Text, options: pluginInfo.getOptionsValue())
                })
        }
    }
}

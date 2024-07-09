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
                    let chatCtx = ChatContext(selectedText: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    await ChatService(prompt: self.prompt, options: pluginInfo.getOptionsValue())!.chat(ctx: chatCtx) { _, ret in
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
                    let chatCtx = ChatContext(selectedText: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    WindowManager.shared.createChatWindow(chatService: chatService, withContext: chatCtx)
                })
        }
    }
}

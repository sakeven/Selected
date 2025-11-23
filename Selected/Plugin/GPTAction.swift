//
//  GPTAction.swift
//  Selected
//
//  Created by sake on 2024/6/2.
//

import Foundation
import Defaults

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
                    let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    await ChatService(prompt: self.prompt, options: pluginInfo.getOptionsValue())!.chat(ctx: chatCtx) { _, ret in
                        if ret.role == .assistant {
                            DispatchQueue.main.async{
                                _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                            }
                            pasteText(ret.message)
                        }
                    }
                })
        } else {
            var chatService: AIProvider = OpenAIProvider(prompt: prompt, options: pluginInfo.getOptionsValue())
            if let tools = tools {
                switch Defaults[.aiService] {
                    case "Claude":
//                        chatService = ClaudeService(prompt: prompt, tools: tools, options: pluginInfo.getOptionsValue())
                        break
                    default:
                        chatService = OpenAIProvider(prompt: prompt, tools: tools, options: pluginInfo.getOptionsValue())
                }
            }

            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                    ChatWindowManager.shared.createChatWindow(chatService: chatService, withContext: chatCtx)
                })
        }
    }
}

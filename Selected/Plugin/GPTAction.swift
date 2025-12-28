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
    var reasoning: Bool?
    var tools: [FunctionDefinition]?

    init(prompt: String) {
        self.prompt = prompt
    }

    func generate(pluginInfo: PluginInfo,  generic: GenericAction) -> PerformAction {
        if generic.after == kAfterPaste  {
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    do {
                        guard let chatService = ChatService(prompt: self.prompt, options: pluginInfo.getOptionsValue()) else {
                            return
                        }
                        for try await event in chatService.chat(ctx: chatCtx) {
                            switch event {
                                case .textDelta(let text):
                                    DispatchQueue.main.async{
                                        _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                                    }
                                    pasteText((text))
                                default:
                                    break
                            }
                        }
                    } catch {
                        AppLogger.plugin.error("PerformAction \(error)")
                    }
                })
        } else {
            let chatService: AIProvider = ChatService(prompt: prompt, tools: tools, options: pluginInfo.getOptionsValue())!
            return PerformAction(
                actionMeta: generic, complete: { ctx in
                    let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID)
                    _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                    ChatWindowManager.shared.createChatWindow(chatService: chatService, withContext: chatCtx)
                })
        }
    }
}

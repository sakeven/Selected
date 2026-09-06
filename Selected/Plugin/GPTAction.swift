import Foundation
import Defaults

struct GptAction: Codable {
    var prompt: String
    var reasoning: Bool?
    var tools: [FunctionDefinition]?

    init(prompt: String) {
        self.prompt = prompt
    }

    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        if let after = generic.after, after != .none {
            return PerformAction(pluginInfo: pluginInfo, actionMeta: generic, complete: { ctx in
                let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID, clipboardText: ctx.ClipboardText ?? "")
                guard let chatService = ChatService(prompt: self.prompt, tools: self.tools,
                                                    options: pluginInfo.getOptionsValue(), reasoning: self.reasoning ?? false) else { return }
                do {
                    var output = ""
                    for try await event in chatService.chat(ctx: chatCtx) {
                        if case .textDelta(let text) = event {
                            if after == .paste {
                                await MainActor.run {
                                    _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                                    if ctx.Editable { pasteText(text) }
                                }
                            } else { output += text }
                        }
                    }
                    let result = output
                    await MainActor.run {
                        if after == .copy { copyText(result) }
                        else if after == .show || after == .xshow {
                            _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
                            WindowManager.shared.createTextWindow(result, editable: after == .xshow && ctx.Editable)
                        }
                    }
                } catch {
                    let message = PluginRedactor(info: pluginInfo, values: pluginInfo.getOptionsValue()).redact(error.localizedDescription)
                    AppLogger.plugin.error("AI action failed: \(message)")
                }
            })
        }
        return PerformAction(pluginInfo: pluginInfo, actionMeta: generic, complete: { ctx in
            guard let chatService = ChatService(prompt: self.prompt, tools: self.tools,
                                                options: pluginInfo.getOptionsValue(), reasoning: self.reasoning ?? true) else { return }
            let chatCtx = ChatContext(text: ctx.Text, webPageURL: ctx.WebPageURL, bundleID: ctx.BundleID, clipboardText: ctx.ClipboardText ?? "")
            _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
            ChatWindowManager.shared.createChatWindow(chatService: chatService, withContext: chatCtx)
        })
    }
}

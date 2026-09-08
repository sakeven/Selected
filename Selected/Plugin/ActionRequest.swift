import AppKit

enum ActionRequest {
    case ai(instruction: String, translation: Bool)
    case plugin(Plugin, Action)

    enum Output {
        case chat, copy, paste, show, xshow, none
    }

    var output: Output {
        switch self {
        case .ai: return .xshow
        case .plugin(_, let action):
            guard action.kind == .gpt || action.kind == .runCommand else { return .none }
            switch action.meta.after ?? .none {
            case .none: return action.kind == .gpt ? .chat : .none
            case .copy: return .copy
            case .paste: return .paste
            case .show: return .show
            case .xshow: return .xshow
            }
        }
    }

    var title: String {
        switch self {
        case .ai: return String(localized: "clip.ai")
        case .plugin(let plugin, let action):
            return PluginTemplate.render(action.meta.title, context: SelectedTextContext(), options: plugin.info.getOptionsValue())
        }
    }

    @MainActor func captureInput(_ input: ActionInput, pasteboard: NSPasteboard = .general) -> ActionInput {
        var result = input
        if case .plugin(_, let action) = self {
            result.context = action.captureContext(input.context, pasteboard: pasteboard)
        } else {
            result.context.ClipboardText = nil
        }
        return result
    }

    @MainActor func perform(input: ActionInput, target: ActionTarget, original: ActionInput? = nil, originalContent: ClipAIContent? = nil,
                            resultPosition: NSPoint = NSEvent.mouseLocation) {
        let session = ActionSession(input: captureInput(input), request: self, target: target, original: original, originalContent: originalContent)
        ClipWindowManager.shared.forceCloseWindow()
        _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
        if output == .xshow || (output == .show && input.source == .clipboard) {
            ActionResultWindow.shared.show(session)
        } else {
            Task {
                await session.run().value
                if session.failed {
                    let message = session.output.isEmpty ? session.message : session.message + "\n\n" + session.output
                    WindowManager.shared.createTextWindow(message, editable: false, at: resultPosition)
                } else if output == .show {
                    WindowManager.shared.createTextWindow(session.output.isEmpty ? session.message : session.output,
                                                          editable: false, at: resultPosition)
                }
            }
        }
    }
}

import Foundation

enum ActionKind: String, CaseIterable, Identifiable {
    case url, service, keycombo, gpt, runCommand
    var id: String { rawValue }
    var title: String {
        switch self {
        case .url: return String(localized: "Open URL")
        case .service: return String(localized: "macOS Service")
        case .keycombo: return String(localized: "Keyboard Shortcut")
        case .gpt: return String(localized: "AI Prompt")
        case .runCommand: return String(localized: "Run Command")
        }
    }
}

extension Action {
    var kind: ActionKind {
        if url != nil { return .url }
        if service != nil { return .service }
        if keycombo != nil { return .keycombo }
        if gpt != nil { return .gpt }
        return .runCommand
    }

    static func new(kind: ActionKind = .url) -> Action {
        var action = Action(meta: GenericAction(title: String(localized: "New Action"), icon: "symbol:bolt",
                                               identifier: "local.action.\(UUID().uuidString.lowercased())"))
        action.setKind(kind)
        return action
    }

    mutating func setKind(_ kind: ActionKind) {
        url = nil
        service = nil
        keycombo = nil
        gpt = nil
        runCommand = nil
        popclip = nil
        meta.after = nil
        meta.includeClipboard = nil
        switch kind {
        case .url: url = URLAction(url: "https://www.google.com/search?q={selected.text}")
        case .service: service = ServiceAction(name: "Make Sticky")
        case .keycombo: keycombo = KeycomboAction(keycombo: "cmd c")
        case .gpt: gpt = GptAction(prompt: String(localized: "Summarize the following:\n{{selected.text}}"))
        case .runCommand: runCommand = RunCommandAction(command: ["/bin/zsh", "-c", "printf '%s' \"$SELECTED_TEXT\""], options: [])
        }
    }
}

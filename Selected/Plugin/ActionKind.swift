import Foundation

enum ActionKind: String, CaseIterable, Identifiable {
    case url, service, keycombo, gpt, runCommand
    var id: String { rawValue }
    var title: String {
        switch self {
        case .url: return "打开链接"
        case .service: return "macOS 服务"
        case .keycombo: return "快捷键"
        case .gpt: return "AI 提示词"
        case .runCommand: return "运行命令"
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
        var action = Action(meta: GenericAction(title: "新动作", icon: "symbol:bolt",
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
        meta.after = nil
        switch kind {
        case .url: url = URLAction(url: "https://www.google.com/search?q={selected.text}")
        case .service: service = ServiceAction(name: "Make Sticky")
        case .keycombo: keycombo = KeycomboAction(keycombo: "cmd c")
        case .gpt: gpt = GptAction(prompt: "请总结以下内容：\n{{selected.text}}")
        case .runCommand: runCommand = RunCommandAction(command: ["/bin/zsh", "-c", "printf '%s' \"$SELECTED_TEXT\""], options: [])
        }
    }
}

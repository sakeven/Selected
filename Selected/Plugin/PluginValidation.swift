import Foundation

struct PluginValidationError: LocalizedError {
    let messages: [String]
    var errorDescription: String? { messages.joined(separator: "\n") }
}

extension Plugin {
    static let currentSchemaVersion = 1
    static let builtInActionIDs: Set<String> = [
        "selected.websearch", "selected.copy", "selected.speak", "selected.openlinks", "selected.map",
        "selected.translation.cn", "selected.translation.en"
    ]

    func validate() throws {
        var errors: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { errors.append(message) }
        }
        func nonempty(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        check((schemaVersion ?? 1) == Self.currentSchemaVersion, "不支持 schemaVersion \(schemaVersion ?? 1)，当前支持版本为 1。")
        check(nonempty(info.name), "插件名称不能为空。")
        if let identifier = info.identifier {
            check(identifier.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil,
                  "插件标识只能包含字母、数字、点和连字符，且须以字母或数字开头。")
        }
        if let version = info.version { check(PluginVersion(version) != nil, "插件版本无效，请使用例如 1.0.0 或 1.1.0-beta.1。") }
        if let minimum = info.minSelectedVersion { check(PluginVersion(minimum) != nil, "最低 Selected 版本无效。") }
        check(!actions.isEmpty, "至少需要一个动作。")
        var actionIDs = Set<String>()
        for action in actions {
            let name = action.meta.title
            check(nonempty(name), "动作标题不能为空。")
            check(nonempty(action.meta.identifier), "动作标识不能为空。")
            check(actionIDs.insert(action.meta.identifier).inserted, "动作标识重复：\(action.meta.identifier)。")
            check(!Self.builtInActionIDs.contains(action.meta.identifier), "动作标识与内置动作冲突：\(action.meta.identifier)。")
            let count = [action.url != nil, action.service != nil, action.keycombo != nil,
                         action.gpt != nil, action.runCommand != nil].filter { $0 }.count
            check(count == 1, "\(name)：必须且只能配置一种动作类型。")
            if let regex = action.meta.regex {
                check((try? Regex(regex)) != nil, "\(name)：正则表达式无效。")
            }
            if let url = action.url {
                let rendered = PluginTemplate.render(url.url, context: SelectedTextContext(Text: "example"),
                                                     options: info.options.reduce(into: [:]) { $0[$1.identifier] = $1.defaultValue }, urlEncoded: true)
                check(nonempty(url.url) && URL(string: rendered)?.scheme != nil, "\(name)：URL 必须包含协议，例如 https://。")
            }
            if let service = action.service { check(nonempty(service.name), "\(name)：服务名称不能为空。") }
            if let command = action.runCommand {
                check(!command.command.isEmpty && nonempty(command.command.first ?? ""), "\(name)：命令不能为空。")
            }
            if let keys = action.keycombo {
                let combos = keys.keycombos ?? (keys.keycombo.isEmpty ? [] : [keys.keycombo])
                check(keys.keycombo.isEmpty || keys.keycombos == nil, "\(name)：keycombo 与 keycombos 只能设置一项。")
                check(!combos.isEmpty && combos.allSatisfy { combo in
                    let tokens = combo.split(separator: " ").map(String.init)
                    return !tokens.isEmpty && tokens.allSatisfy { KeyMaskMapping[$0] != nil || KeycodeMapping[$0] != nil }
                        && tokens.filter { KeycodeMapping[$0] != nil && KeyMaskMapping[$0] == nil }.count == 1
                }, "\(name)：快捷键无效，请使用例如 cmd shift c，每个组合只能有一个普通按键。")
            }
            if let gpt = action.gpt {
                check(nonempty(gpt.prompt), "\(name)：AI 提示词不能为空。")
                for tool in gpt.tools ?? [] {
                    check(tool.getParameters() != nil, "\(name)：工具 \(tool.name) 的 JSON Schema 无效。")
                    if let command = tool.command {
                        check(!command.isEmpty && nonempty(command.first ?? ""), "\(name)：工具 \(tool.name) 的命令不能为空。")
                    }
                }
            }
            if let after = action.meta.after, after != .none {
                check(action.runCommand != nil || action.gpt != nil, "\(name)：结果处理仅适用于命令和 AI 动作。")
            }
        }
        var optionIDs = Set<String>()
        for option in info.options {
            check(option.identifier.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil,
                  "选项标识 \(option.identifier) 无效，请使用字母、数字和下划线，且不能以数字开头。")
            check(optionIDs.insert(option.identifier.uppercased()).inserted, "选项标识重复（忽略大小写）：\(option.identifier)。")
            if option.type == .boolean, let value = option.defaultVal {
                check(["true", "false"].contains(value), "\(option.identifier)：开关默认值须为 true 或 false。")
            }
            if option.type == .multiple {
                let values = option.values ?? []
                check(!values.isEmpty && Set(values).count == values.count, "\(option.identifier)：单选必须有不重复的候选值。")
                if let value = option.defaultVal { check(values.contains(value), "\(option.identifier)：默认值不在候选值中。") }
                if let labels = option.valueLabels { check(labels.count == values.count, "\(option.identifier)：显示名称数量必须与候选值一致。") }
            }
            check(option.type != .secret || option.defaultVal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false, "\(option.identifier)：密钥不能写入默认值，请在配置页输入。")
        }
        if !errors.isEmpty { throw PluginValidationError(messages: errors) }
    }

    func compatibilityIssue(hostVersion: String) -> String? {
        guard let minimum = info.minSelectedVersion, let required = PluginVersion(minimum),
              let current = PluginVersion(hostVersion), current < required else { return nil }
        return "需要 Selected \(minimum) 或更新版本，当前为 \(hostVersion)。"
    }
}

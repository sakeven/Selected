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
        check((schemaVersion ?? 1) == Self.currentSchemaVersion, String(localized: "Unsupported schemaVersion \(schemaVersion ?? 1). The supported version is 1."))
        check(nonempty(info.name), String(localized: "The plugin name cannot be empty."))
        if let identifier = info.identifier {
            check(identifier.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil,
                  String(localized: "The plugin identifier can contain only letters, numbers, dots, and hyphens, and must start with a letter or number."))
        }
        if let version = info.version { check(PluginVersion(version) != nil, String(localized: "Invalid plugin version. Use a version such as 1.0.0 or 1.1.0-beta.1.")) }
        if let minimum = info.minSelectedVersion { check(PluginVersion(minimum) != nil, String(localized: "Invalid minimum Selected version.")) }
        check(!actions.isEmpty, String(localized: "At least one action is required."))
        var actionIDs = Set<String>()
        for action in actions {
            let name = action.meta.title
            check(nonempty(name), String(localized: "The action title cannot be empty."))
            check(nonempty(action.meta.identifier), String(localized: "The action identifier cannot be empty."))
            check(actionIDs.insert(action.meta.identifier).inserted, String(localized: "Duplicate action identifier: \(action.meta.identifier)."))
            check(!Self.builtInActionIDs.contains(action.meta.identifier), String(localized: "Action identifier conflicts with a built-in action: \(action.meta.identifier)."))
            let count = [action.url != nil, action.service != nil, action.keycombo != nil,
                         action.gpt != nil, action.runCommand != nil].filter { $0 }.count
            check(count == 1, String(localized: "\(name): Configure exactly one action type."))
            if let regex = action.meta.regex {
                check((try? Regex(regex)) != nil, String(localized: "\(name): Invalid regular expression."))
            }
            if let url = action.url {
                let rendered = PluginTemplate.render(url.url, context: SelectedTextContext(Text: "example"),
                                                     options: info.options.reduce(into: [:]) { $0[$1.identifier] = $1.defaultValue }, urlEncoded: true)
                check(nonempty(url.url) && URL(string: rendered)?.scheme != nil, String(localized: "\(name): The URL must include a scheme, such as https://."))
            }
            if let service = action.service { check(nonempty(service.name), String(localized: "\(name): The service name cannot be empty.")) }
            if let command = action.runCommand {
                check(!command.command.isEmpty && nonempty(command.command.first ?? ""), String(localized: "\(name): The command cannot be empty."))
            }
            if let keys = action.keycombo {
                let combos = keys.keycombos ?? (keys.keycombo.isEmpty ? [] : [keys.keycombo])
                check(keys.keycombo.isEmpty || keys.keycombos == nil, String(localized: "\(name): Set either keycombo or keycombos, not both."))
                check(!combos.isEmpty && combos.allSatisfy { combo in
                    let tokens = combo.split(separator: " ").map(String.init)
                    return !tokens.isEmpty && tokens.allSatisfy { KeyMaskMapping[$0] != nil || KeycodeMapping[$0] != nil }
                        && tokens.filter { KeycodeMapping[$0] != nil && KeyMaskMapping[$0] == nil }.count == 1
                }, String(localized: "\(name): Invalid shortcut. Use a shortcut such as cmd shift c, with exactly one non-modifier key per combination."))
            }
            if let gpt = action.gpt {
                check(nonempty(gpt.prompt), String(localized: "\(name): The AI prompt cannot be empty."))
                for tool in gpt.tools ?? [] {
                    check(tool.getParameters() != nil, String(localized: "\(name): Invalid JSON Schema for tool \(tool.name)."))
                    if let command = tool.command {
                        check(!command.isEmpty && nonempty(command.first ?? ""), String(localized: "\(name): The command for tool \(tool.name) cannot be empty."))
                    }
                }
            }
            if let after = action.meta.after, after != .none {
                check(action.runCommand != nil || action.gpt != nil, String(localized: "\(name): Output handling is available only for command and AI actions."))
            }
        }
        var optionIDs = Set<String>()
        for option in info.options {
            check(option.identifier.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil,
                  String(localized: "Invalid option identifier \(option.identifier). Use letters, numbers, and underscores, and do not start with a number."))
            check(optionIDs.insert(option.identifier.uppercased()).inserted, String(localized: "Duplicate option identifier (case-insensitive): \(option.identifier)."))
            if option.type == .boolean, let value = option.defaultVal {
                check(["true", "false"].contains(value), String(localized: "\(option.identifier): The default toggle value must be true or false."))
            }
            if option.type == .multiple {
                let values = option.values ?? []
                check(!values.isEmpty && Set(values).count == values.count, String(localized: "\(option.identifier): Single-choice options require unique choices."))
                if let value = option.defaultVal { check(values.contains(value), String(localized: "\(option.identifier): The default value is not one of the choices.")) }
                if let labels = option.valueLabels { check(labels.count == values.count, String(localized: "\(option.identifier): The number of display labels must match the number of choices.")) }
            }
            check(option.type != .secret || option.defaultVal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false, String(localized: "\(option.identifier): Secrets cannot have a default value. Enter the secret on the configuration page."))
        }
        if !errors.isEmpty { throw PluginValidationError(messages: errors) }
    }

    func compatibilityIssue(hostVersion: String) -> String? {
        guard let minimum = info.minSelectedVersion, let required = PluginVersion(minimum),
              let current = PluginVersion(hostVersion), current < required else { return nil }
        return String(localized: "Requires Selected \(minimum) or later. The current version is \(hostVersion).")
    }
}

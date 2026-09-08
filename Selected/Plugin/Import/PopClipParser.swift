import AppKit
import CryptoKit

struct PopClipParser {
    let package: URL
    let result: PopClipImport
    let actionKeys: Set<String> = ["title", "icon", "identifier", "requirements", "regex", "requiredapps", "excludedapps", "url", "cleanquery", "spacesasplus", "servicename", "keycombo", "keycombos", "keycombotarget"]

    mutating func parse(_ dictionary: [String: Any]) throws -> Plugin {
        let config = try normalized(dictionary)
        let metadata: Set<String> = ["name", "description", "identifier", "icon", "options", "action", "actions", "popclipversion", "macosversion", "keywords"]
        try rejectUnknown(config, allowed: metadata.union(actionKeys))
        var info = PluginInfo()
        info.name = try localized(config["name"])
        let sourceID = try string(config["identifier"]) ?? package.lastPathComponent
        info.identifier = "popclip." + SHA256.hash(data: Data(sourceID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        info.description = try config["description"].map { try localized($0) }
        info.version = "1.0.0"
        if let minimum = try string(config["macosversion"]) {
            guard let version = PluginVersion(minimum) else { throw failure("macOS version") }
            let system = ProcessInfo.processInfo.operatingSystemVersion
            let current = PluginVersion("\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)")!
            guard current >= version else { throw failure("Requires macOS \(minimum)") }
        }
        if config["popclipversion"] != nil {
            guard let minimum = config["popclipversion"] as? NSNumber, minimum.doubleValue > 0,
                  minimum.doubleValue == Double(minimum.intValue) else { throw failure("PopClip version") }
            result.notes.append(String(localized: "Compatibility is checked by capability. The PopClip host version is retained in the original source."))
        }
        if let raw = config["options"] {
            guard let options = raw as? [[String: Any]] else { throw failure("options") }
            info.options = try options.map { try option($0) }
        }
        let rawActions: [[String: Any]]
        guard config["action"] == nil || config["actions"] == nil else { throw failure("action + actions") }
        if let value = config["actions"] ?? config["action"] {
            if let array = value as? [[String: Any]] { rawActions = array }
            else if let single = value as? [String: Any] { rawActions = [single] }
            else { throw failure("actions") }
        } else { rawActions = [[:]] }
        var actions: [Action] = []
        for (index, raw) in rawActions.enumerated() {
            let individual = try normalized(raw)
            try rejectUnknown(individual, allowed: actionKeys)
            var values = config.filter { actionKeys.contains($0.key) }
            values.removeValue(forKey: "identifier")
            values.merge(individual) { _, new in new }
            let title = try values["title"].map { try localized($0) } ?? info.name
            let actionID = try string(individual["identifier"]) ?? String(index + 1)
            var action = Action(meta: GenericAction(title: title, icon: try icon(values["icon"]), identifier: info.id + "." + actionID))
            action.meta.requiredApps = try strings(values["requiredapps"])
            action.meta.excludedApps = try strings(values["excludedapps"])
            var adapter = PopClipAction()
            adapter.requirements = try strings(values["requirements"]) ?? ["text"]
            adapter.regex = try string(values["regex"])
            adapter.cleanQuery = try boolean(values["cleanquery"]) ?? false
            adapter.spacesAsPlus = try boolean(values["spacesasplus"]) ?? false
            adapter.keyComboTarget = try string(values["keycombotarget"]) ?? "session"
            try adapter.validate()
            action.popclip = adapter
            if let url = try string(values["url"]) {
                action.url = URLAction(url: try template(url, options: info.options))
            }
            if let service = try string(values["servicename"]) { action.service = ServiceAction(name: service) }
            if let combo = try string(values["keycombo"]) { action.keycombo = KeycomboAction(keycombo: keyCombo(combo)) }
            if let combos = try strings(values["keycombos"]) {
                guard action.keycombo == nil else { throw failure("key combo + key combos") }
                action.keycombo = KeycomboAction(keycombos: combos.map(keyCombo))
            }
            actions.append(action)
        }
        info.icon = try config["icon"].map { try icon($0) } ?? actions.first?.meta.icon ?? info.icon
        let plugin = Plugin(info: info, actions: actions, importedFrom: result.sourceName)
        try plugin.validate()
        result.notes.append(String(localized: "The original package is preserved. Options use Selected's settings and local Keychain."))
        return plugin
    }

    func normalized(_ dictionary: [String: Any]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        let aliases = ["id": "identifier", "imagefile": "icon", "blockedapps": "excludedapps", "regularexpression": "regex", "requiredosversion": "macosversion", "requiredsoftwareversion": "popclipversion", "passhtml": "capturehtml", "js": "javascript"]
        for (key, value) in dictionary {
            var name = key.lowercased().filter { !" _-".contains($0) }
            if name.hasPrefix("extension") { name = String(name.dropFirst(9)) }
            if name.hasPrefix("option"), name != "options" { name = String(name.dropFirst(6)) }
            name = aliases[name] ?? name
            guard result[name] == nil else { throw failure(key) }
            if !(value is NSNull) { result[name] = value }
        }
        return result
    }

    func rejectUnknown(_ values: [String: Any], allowed: Set<String>) throws {
        let unknown = Set(values.keys).subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            throw PluginValidationError(messages: unknown.map { String(localized: "Not supported in this import: \($0)") })
        }
    }

    func localized(_ value: Any?) throws -> String {
        if let text = value as? String { return text }
        if let values = value as? [String: String], let fallback = values["en"] {
            for language in Locale.preferredLanguages {
                var components = language.lowercased().split(separator: "-").map(String.init)
                while !components.isEmpty {
                    if let match = values[components.joined(separator: "-")] { return match }
                    components.removeLast()
                }
            }
            return fallback
        }
        throw failure("localized text")
    }

    func string(_ value: Any?) throws -> String? {
        guard let value else { return nil }
        guard let string = value as? String else { throw failure("text value") }
        return string
    }

    func strings(_ value: Any?) throws -> [String]? {
        guard let value else { return nil }
        guard let strings = value as? [String] else { throw failure("list value") }
        return strings
    }

    func boolean(_ value: Any?) throws -> Bool? {
        guard let value else { return nil }
        if let string = value as? String, ["true", "false", "1", "0"].contains(string) { return string == "true" || string == "1" }
        if let number = value as? NSNumber, [0.0, 1.0].contains(number.doubleValue) { return number.boolValue }
        throw failure("boolean value")
    }

    func option(_ dictionary: [String: Any]) throws -> Option {
        let values = try normalized(dictionary)
        try rejectUnknown(values, allowed: ["identifier", "type", "label", "description", "defaultvalue", "values", "valuelabels", "multiline", "keychain"])
        guard let identifier = try string(values["identifier"]), let typeName = try string(values["type"]), let type = OptionType(rawValue: typeName) else { throw failure("option type or identifier") }
        var option = Option(identifier: identifier, type: type)
        option.label = try values["label"].map { try localized($0) }
        option.description = try values["description"].map { try localized($0) }
        option.defaultVal = type == .boolean ? (try boolean(values["defaultvalue"]) ?? true).description : try string(values["defaultvalue"])
        option.values = try strings(values["values"])
        option.valueLabels = try strings(values["valuelabels"])
        option.multiline = try boolean(values["multiline"])
        if let keychain = try string(values["keychain"]), !["local", "sync"].contains(keychain) { throw failure("keychain") }
        return option
    }

    func icon(_ value: Any?) throws -> String {
        guard let value, !(value is NSNumber) else { return "symbol:puzzlepiece.extension" }
        let name = try localized(value)
        if name.hasPrefix("symbol:"), NSImage(systemSymbolName: String(name.dropFirst(7)), accessibilityDescription: nil) != nil { return name }
        if name.hasPrefix("square ") || name.hasPrefix("circle ") { return name }
        let resource = package.appendingPathComponent(name).standardizedFileURL
        if !name.hasPrefix("/"), resource.path.hasPrefix(package.path + "/"), NSImage(contentsOf: resource) != nil {
            return "file://./PopClip Source/" + package.lastPathComponent + "/" + name
        }
        result.notes.append(String(localized: "Icon replaced with a system icon: \(name)"))
        return "symbol:puzzlepiece.extension"
    }

    func template(_ input: String, options: [Option]) throws -> String {
        let expression = try NSRegularExpression(pattern: #"\*\*\*|\{popclip ([^}]+)\}"#)
        var output = input
        for match in expression.matches(in: input, range: NSRange(input.startIndex..., in: input)).reversed() {
            let range = Range(match.range, in: output)!
            let variable = Range(match.range(at: 1), in: input).map { String(input[$0]).lowercased() } ?? "text"
            let replacement: String
            switch variable {
            case "text": replacement = "{selected.text}"
            case "browser url": replacement = "{selected.webPageURL}"
            case "bundle identifier": replacement = "{selected.bundleID}"
            default:
                guard variable.hasPrefix("option "), let option = options.first(where: { $0.identifier.lowercased() == String(variable.dropFirst(7)) }) else { throw failure(variable) }
                replacement = "{selected.options." + option.identifier + "}"
            }
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    func keyCombo(_ value: String) -> String {
        let aliases = ["command": "cmd", "control": "ctr", "ctrl": "ctr", "opt": "option"]
        return value.lowercased().split(whereSeparator: \.isWhitespace).map { aliases[String($0)] ?? String($0) }.joined(separator: " ")
    }

    func failure(_ field: String) -> PluginValidationError {
        PluginValidationError(messages: [String(localized: "Unsupported or invalid PopClip field: \(field)")])
    }
}

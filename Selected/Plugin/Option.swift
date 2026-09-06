import Foundation

struct Option: Codable, Identifiable {
    var id = UUID()
    var identifier: String
    var type: OptionType
    var label: String?
    var description: String?
    var defaultVal: String?
    var values: [String]?
    var valueLabels: [String]?
    var multiline: Bool?

    enum CodingKeys: String, CodingKey {
        case identifier, type, label, description, defaultVal, values, valueLabels, multiline
    }

    var displayName: String { label.flatMap { $0.isEmpty ? nil : $0 } ?? identifier }

    var defaultValue: String {
        switch type {
        case .boolean: return defaultVal == "true" ? "true" : "false"
        case .multiple: return defaultVal ?? values?.first ?? ""
        case .secret: return ""
        case .string: return defaultVal ?? ""
        }
    }

    func value(pluginID: String) -> String {
        let defaults = UserDefaults(suiteName: defaultsSuiteName(pluginID))
        if type == .secret {
            do {
                if let value = try PluginSecretStore.read(pluginID: pluginID, key: identifier) { return value }
                if let legacy = defaults?.string(forKey: identifier) {
                    try PluginSecretStore.write(legacy, pluginID: pluginID, key: identifier)
                    defaults?.removeObject(forKey: identifier)
                    return legacy
                }
            } catch {
                AppLogger.plugin.error("Cannot read plugin secret: \(error.localizedDescription)")
            }
            return ""
        }
        guard let stored = defaults?.object(forKey: identifier) else { return defaultValue }
        if type == .boolean {
            return (stored as? Bool ?? (stored as? String == "true")).description
        }
        let value = stored as? String ?? defaultValue
        if type == .multiple, !(values ?? []).contains(value) { return defaultValue }
        return value
    }

    func save(_ value: String, pluginID: String) throws {
        let defaults = UserDefaults(suiteName: defaultsSuiteName(pluginID))
        if type == .secret {
            try PluginSecretStore.write(value, pluginID: pluginID, key: identifier)
            defaults?.removeObject(forKey: identifier)
        } else if type == .boolean {
            defaults?.set(value == "true", forKey: identifier)
        } else {
            defaults?.set(value, forKey: identifier)
        }
    }
}

enum OptionType: String, Codable, CaseIterable {
    case string, boolean, multiple, secret

    var title: String {
        switch self {
        case .string: return String(localized: "Text")
        case .boolean: return String(localized: "Toggle")
        case .multiple: return String(localized: "Single Choice")
        case .secret: return String(localized: "Secret")
        }
    }
}

func defaultsSuiteName(_ pluginID: String) -> String {
    SelfBundleID + "." + pluginID
}

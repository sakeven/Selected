import Foundation

struct SupportedApp: Codable {
    var bundleID: String
}

struct Supported: Codable {
    var apps: [SupportedApp]?
    var urls: [String]?

    func match(url: String, bundleID: String) -> Bool {
        let apps = apps ?? []
        let urls = urls ?? []
        return (apps.isEmpty && urls.isEmpty)
            || apps.contains { $0.bundleID == bundleID }
            || urls.contains { !url.isEmpty && url.contains($0) }
    }
}

struct PluginInfo: Codable {
    var identifier: String?
    var icon = "symbol:puzzlepiece.extension"
    var name = "system"
    var version: String?
    var minSelectedVersion: String?
    var description: String?
    var options: [Option] = []
    var enabled = true
    var pluginDir = ""

    var id: String { identifier ?? name }

    enum CodingKeys: String, CodingKey {
        case identifier, icon, name, version, minSelectedVersion, description, options, enabled
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try values.decodeIfPresent(String.self, forKey: .identifier)
        icon = try values.decodeIfPresent(String.self, forKey: .icon) ?? icon
        name = try values.decode(String.self, forKey: .name)
        version = try values.decodeIfPresent(String.self, forKey: .version)
        minSelectedVersion = try values.decodeIfPresent(String.self, forKey: .minSelectedVersion)
        description = try values.decodeIfPresent(String.self, forKey: .description)
        options = try values.decodeIfPresent([Option].self, forKey: .options) ?? []
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }

    func getOptionsValue() -> [String: String] {
        Dictionary(uniqueKeysWithValues: options.map { ($0.identifier, $0.value(pluginID: id)) })
    }
}

struct Plugin: Codable, Identifiable {
    var schemaVersion: Int? = 1
    var info: PluginInfo
    var actions: [Action]
    var source: Data?

    enum CodingKeys: String, CodingKey {
        case schemaVersion, info, actions
    }

    var id: String { info.id }

    static func new() -> Plugin {
        var info = PluginInfo()
        info.identifier = "local.\(UUID().uuidString.lowercased())"
        info.name = "新插件"
        info.version = "1.0.0"
        return Plugin(info: info, actions: [Action.new()])
    }
}

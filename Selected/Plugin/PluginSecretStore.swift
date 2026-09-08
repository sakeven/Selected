import Foundation

struct PluginSecretStore {
    private static func storage(pluginID: String) -> KeychainSecretStorage {
        KeychainSecretStorage(service: SelfBundleID + ".plugins." + pluginID)
    }

    static func read(pluginID: String, key: String) throws -> String? {
        try storage(pluginID: pluginID).read(account: key)
    }

    static func write(_ value: String, pluginID: String, key: String) throws {
        try storage(pluginID: pluginID).write(value, account: key)
    }

    static func remove(pluginID: String) throws {
        try storage(pluginID: pluginID).removeAll()
    }
}

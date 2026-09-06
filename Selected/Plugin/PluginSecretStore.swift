import Foundation
import Security

struct PluginSecretStore {
    private static func query(pluginID: String, key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: SelfBundleID + ".plugins." + pluginID,
         kSecAttrAccount as String: key]
    }

    static func read(pluginID: String, key: String) throws -> String? {
        var query = query(pluginID: pluginID, key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw error(status) }
        return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func write(_ value: String, pluginID: String, key: String) throws {
        let query = query(pluginID: pluginID, key: key)
        let attributes = [kSecValueData as String: Data(value.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw error(status) }
    }

    static func remove(pluginID: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: SelfBundleID + ".plugins." + pluginID]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw error(status) }
    }

    private static func error(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
            NSLocalizedDescriptionKey: (SecCopyErrorMessageString(status, nil) as String?) ?? String(localized: "Keychain access failed")
        ])
    }
}

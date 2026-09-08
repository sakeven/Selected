import Foundation

struct APIKeyStore {
    enum Provider: String, CaseIterable {
        case openAI = "OpenAIAPIKey"
        case claude = "ClaudeAPIKey"
        case gemini = "GeminiAPIKey"
    }

    static let shared = APIKeyStore()

    private let storage: any SecretStorage
    private let defaults: UserDefaults
    private let runtime: AppRuntimeMode

    init(storage: any SecretStorage = KeychainSecretStorage(service: SelfBundleID + ".api-keys"),
         defaults: UserDefaults = .standard, runtime: AppRuntimeMode = .current) {
        self.storage = storage
        self.defaults = defaults
        self.runtime = runtime
    }

    func value(for provider: Provider) -> String {
        guard runtime == .normal else { return "" }
        do {
            if let value = try storage.read(account: provider.rawValue) { return value }
        } catch {
            logger.error("Unable to read API credential: \(error.localizedDescription)")
        }
        // Keep an existing credential usable if its Keychain migration has not succeeded.
        return defaults.string(forKey: provider.rawValue) ?? ""
    }

    func save(_ value: String, for provider: Provider) throws {
        guard runtime == .normal else { return }
        if value.isEmpty {
            try storage.remove(account: provider.rawValue)
        } else {
            try storage.write(value, account: provider.rawValue)
        }
        defaults.removeObject(forKey: provider.rawValue)
    }

    func migrateLegacyValues() throws {
        guard runtime == .normal else { return }
        for provider in Provider.allCases {
            guard let legacy = defaults.string(forKey: provider.rawValue) else { continue }
            if !legacy.isEmpty, try storage.read(account: provider.rawValue) == nil {
                try storage.write(legacy, account: provider.rawValue)
            }
            defaults.removeObject(forKey: provider.rawValue)
        }
    }
}

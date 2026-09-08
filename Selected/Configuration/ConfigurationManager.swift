import Foundation

// ConfigurationManager 读取、保存应用的复杂配置，比如什么应用下启用哪些 action 等等。
// 配置保存在 "Library/Application Support/Selected" 下。
class ConfigurationManager {
    static let shared = ConfigurationManager()
    private let fileURL: URL

    var userConfiguration: UserConfiguration

    init(fileURL: URL = appSupportURL.appendingPathComponent("UserConfiguration.json")) {
        self.fileURL = fileURL
        userConfiguration = UserConfiguration(defaultActions: [], appConditions: [], urlConditions: [])
        loadConfiguration()
    }

    func getAppCondition(bundleID: String) -> AppCondition? {
        userConfiguration.appCondition(bundleID: bundleID)
    }

    func getURLCondition(url: String) -> URLCondition? {
        userConfiguration.urlCondition(url: url)
    }

    func loadConfiguration() {
        print("UserConfiguration \(fileURL.absoluteString)")
        do {
            let data = try Data(contentsOf: fileURL)
            userConfiguration = try JSONDecoder().decode(UserConfiguration.self, from: data)
        } catch {
            print("Error loading configuration: \(error)")
        }
    }

    func saveConfiguration() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(userConfiguration)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}

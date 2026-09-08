import Foundation
import Defaults

struct PluginRedactor {
    let secrets: [String]

    init(secrets: [String]) { self.secrets = secrets }

    init(info: PluginInfo, values: [String: String]) {
        secrets = info.options.filter { $0.type == .secret }.compactMap { values[$0.identifier] }
            + [APIKeyStore.shared.value(for: .openAI), APIKeyStore.shared.value(for: .claude)]
    }

    func redact(_ text: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let values = Set(secrets.filter { !$0.isEmpty }.flatMap { secret in
            [secret, secret.addingPercentEncoding(withAllowedCharacters: allowed) ?? secret]
        }).sorted { $0.count > $1.count }
        return values.reduce(text) { $0.replacingOccurrences(of: $1, with: "••••") }
    }
}

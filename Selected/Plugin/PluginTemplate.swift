import Foundation

struct PluginTemplate {
    static func render(_ template: String, context: SelectedTextContext,
                       options: [String: String], urlEncoded: Bool = false) -> String {
        var values = options.reduce(into: [String: String]()) { result, option in
            result["selected.options." + option.key] = option.value
        }
        values["selected.text"] = context.Text
        values["text"] = context.Text
        values["selected.bundleID"] = context.BundleID
        values["selected.webPageURL"] = context.WebPageURL
        let pattern = #"\{(text|selected\.[A-Za-z0-9_.-]+)\}"#
        let regex = try! NSRegularExpression(pattern: pattern)
        var result = template
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        for match in regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                  let value = values[String(template[keyRange])],
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: urlEncoded ? value.addingPercentEncoding(withAllowedCharacters: allowed)! : value)
        }
        return result
    }
}

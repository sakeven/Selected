import AppKit

struct PopClipAction: Codable {
    var requirements: [String] = ["text"]
    var regex: String?
    var cleanQuery = false
    var spacesAsPlus = false
    var keyComboTarget = "session"

    func validate() throws {
        for requirement in requirements {
            let value = requirement.hasPrefix("!") ? String(requirement.dropFirst()) : requirement
            guard ["text", "copy", "paste", "url", "isurl", "urls", "email", "emails"].contains(value)
                    || (value.hasPrefix("option-") && value.contains("=")) else {
                throw PluginValidationError(messages: [String(localized: "Unsupported PopClip requirement: \(requirement)")])
            }
        }
        if let regex { _ = try NSRegularExpression(pattern: regex) }
        guard ["session", "hid"].contains(keyComboTarget) else {
            throw PluginValidationError(messages: [String(localized: "Unsupported PopClip key target: \(keyComboTarget)")])
        }
    }

    func prepare(_ context: SelectedTextContext, options: [String: String]) throws -> SelectedTextContext {
        var result = context
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector.matches(in: context.Text, range: NSRange(context.Text.startIndex..., in: context.Text))
        let urls = links.filter { ["http", "https"].contains($0.url?.scheme?.lowercased() ?? "") }
        let emails = links.filter { $0.url?.scheme == "mailto" }
        for requirement in requirements {
            let negated = requirement.hasPrefix("!")
            let value = negated ? String(requirement.dropFirst()) : requirement
            let matches: Bool
            var narrowed: String?
            switch value {
            case "text", "copy": matches = !context.Text.isEmpty
            case "paste": matches = context.Editable
            case "url", "isurl":
                let match = urls.first
                let range = match.flatMap { Range($0.range, in: context.Text) }
                matches = urls.count == 1 && (value != "isurl" || range.map {
                    context.Text.trimmingCharacters(in: .whitespacesAndNewlines) == String(context.Text[$0])
                } == true)
                narrowed = match?.url?.absoluteString
                if let url = narrowed, url.hasPrefix("http://"), let range,
                   !context.Text[range].lowercased().hasPrefix("http://") {
                    narrowed = "https://" + url.dropFirst(7)
                }
            case "urls": matches = !urls.isEmpty
            case "email":
                matches = emails.count == 1
                narrowed = emails.first.flatMap { Range($0.range, in: context.Text) }.map { String(context.Text[$0]) }
            case "emails": matches = !emails.isEmpty
            default:
                let parts = value.dropFirst("option-".count).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                matches = parts.count == 2 && options[String(parts[0])] == String(parts[1])
            }
            guard matches != negated else {
                throw PluginValidationError(messages: [String(localized: "Condition not met: \(requirement)")])
            }
            if !negated, let narrowed { result.Text = narrowed }
        }
        if let regex {
            let expression = try NSRegularExpression(pattern: regex)
            guard let match = expression.firstMatch(in: result.Text, range: NSRange(result.Text.startIndex..., in: result.Text)),
                  let range = Range(match.range, in: result.Text) else {
                throw PluginValidationError(messages: [String(localized: "The text does not match the regular expression.")])
            }
            result.Text = String(result.Text[range])
        }
        return result
    }

    func renderURL(_ template: String, context: SelectedTextContext, options: [String: String], exactPhrase: Bool = false) -> String {
        var context = context
        context.Text = context.Text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery {
            context.Text = context.Text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }
        if exactPhrase { context.Text = "\"" + context.Text + "\"" }
        return PluginTemplate.render(template, context: context, options: options, urlEncoded: true, spacesAsPlus: spacesAsPlus)
    }

    static func optionValues(_ info: PluginInfo, values: [String: String]) -> [String: String] {
        var result = values
        for option in info.options where option.type == .boolean {
            result[option.identifier] = values[option.identifier] == "true" ? "1" : "0"
        }
        return result
    }
}

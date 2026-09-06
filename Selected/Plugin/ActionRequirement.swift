import Foundation

enum ActionRequirement: String, Codable, CaseIterable {
    case text, editable, url, urls

    var title: String {
        switch self {
        case .text: return String(localized: "Text is selected")
        case .editable: return String(localized: "Text can be pasted")
        case .url: return String(localized: "Contains one link")
        case .urls: return String(localized: "Contains links")
        }
    }
}

extension GenericAction {
    func matches(_ context: SelectedTextContext) -> Bool {
        unavailableReason(context) == nil
    }

    func unavailableReason(_ context: SelectedTextContext) -> String? {
        if let apps = requiredApps, !apps.isEmpty, !apps.contains(context.BundleID) {
            return String(localized: "This action is not enabled for the selected app.")
        }
        if excludedApps?.contains(context.BundleID) == true {
            return String(localized: "This action is hidden in the selected app.")
        }
        for requirement in requirements ?? [] {
            let matches: Bool
            switch requirement {
            case .text: matches = !context.Text.isEmpty
            case .editable: matches = context.Editable
            case .url: matches = context.URLs.count == 1
            case .urls: matches = !context.URLs.isEmpty
            }
            if !matches { return String(localized: "Condition not met: \(requirement.title)") }
        }
        if let regex, let expression = try? Regex(regex), !context.Text.contains(expression) {
            return String(localized: "The text does not match the regular expression.")
        }
        return nil
    }
}

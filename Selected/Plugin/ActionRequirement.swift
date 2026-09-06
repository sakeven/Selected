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
        if let apps = requiredApps, !apps.isEmpty, !apps.contains(context.BundleID) { return false }
        if excludedApps?.contains(context.BundleID) == true { return false }
        return (requirements ?? []).allSatisfy { requirement in
            switch requirement {
            case .text: return !context.Text.isEmpty
            case .editable: return context.Editable
            case .url: return context.URLs.count == 1
            case .urls: return !context.URLs.isEmpty
            }
        }
    }
}

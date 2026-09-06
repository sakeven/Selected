import Foundation

enum ActionRequirement: String, Codable, CaseIterable {
    case text, editable, url, urls

    var title: String {
        switch self {
        case .text: return "有选中文本"
        case .editable: return "可粘贴文本"
        case .url: return "包含一个链接"
        case .urls: return "包含链接"
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

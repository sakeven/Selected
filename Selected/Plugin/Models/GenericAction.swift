import Foundation
import AppKit

enum AfterAction: String, Codable, CaseIterable {
    case none = ""
    case paste
    case copy
    case show
    case xshow
}


struct GenericAction: Codable {
    var title: String
    var icon: String
    var after: AfterAction?
    var identifier: String
    var regex: String?
    var description: String?
    var requirements: [ActionRequirement]?
    var requiredApps: [String]?
    var excludedApps: [String]?
    var includeClipboard: Bool?

    init(title: String, icon: String, after: AfterAction? = nil , identifier: String) {
        self.title = title
        self.icon = icon
        self.after = after
        self.identifier = identifier
    }

    init(title: String, icon: String, after: AfterAction? = nil, identifier: String, regex: String) {
        self.title = title
        self.icon = icon
        self.after = after
        self.identifier = identifier
        self.regex = regex
    }

    static func == (lhs: GenericAction, rhs: GenericAction) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

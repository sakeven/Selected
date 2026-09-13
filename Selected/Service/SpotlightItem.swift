import Foundation

struct SpotlightItem: Identifiable {
    enum Content {
        case application(URL), file(URL), action(PerformAction), clipboard(ClipHistoryData), more(Group), textActions
    }

    enum Group: String, CaseIterable {
        case applications, actions, files, clipboard

        var title: String {
            switch self {
            case .applications: return String(localized: "Applications")
            case .actions: return String(localized: "Actions")
            case .files: return String(localized: "Files and Folders")
            case .clipboard: return String(localized: "Clipboard")
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let content: Content
    var searchNames: [String] = []

    var url: URL? {
        switch content {
        case .application(let url), .file(let url): return url
        default: return nil
        }
    }

    var group: Group? {
        switch content {
        case .application: return .applications
        case .file: return .files
        case .action: return .actions
        case .clipboard: return .clipboard
        case .more(let group): return group
        case .textActions: return nil
        }
    }

    static func action(_ action: PerformAction) -> Self {
        Self(id: "action:" + action.actionMeta.identifier, title: action.actionMeta.title,
             subtitle: action.actionMeta.description ?? action.pluginInfo?.name ?? String(localized: "Selected action"),
             content: .action(action), searchNames: [action.pluginInfo?.name ?? ""])
    }

    static func file(_ url: URL) -> Self {
        Self(id: "file:" + url.path, title: url.lastPathComponent,
             subtitle: (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
             content: .file(url))
    }

    @MainActor static func clipboard(_ clip: ClipHistoryData) -> Self {
        Self(id: "clipboard:" + clip.objectID.uriRepresentation().absoluteString,
             title: String((clip.cleanedPreviewText?.removingAllNewlines() ?? clip.rowTitle).prefix(160)),
             subtitle: clip.contentTypeLabel + " · " + clip.appDisplayName,
             content: .clipboard(clip))
    }

    static func more(_ group: Group) -> Self {
        Self(id: "more:" + group.rawValue, title: String(localized: "More Results…"),
             subtitle: String(localized: "Search in this category"), content: .more(group))
    }

    func matchScore(_ query: String) -> Int? {
        let query = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return ([title] + searchNames).compactMap { name -> Int? in
            let name = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if name == query { return 0 }
            if name.hasPrefix(query) { return 1 }
            let initials = name.split { !$0.isLetter && !$0.isNumber }.compactMap(\.first)
            if query.count > 1, String(initials).hasPrefix(query) { return 2 }
            if name.contains(query) { return 3 }
            return nil
        }.min()
    }
}

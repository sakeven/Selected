import Foundation

struct ActionCatalog {
    struct Entry: Identifiable {
        let id: String
        let title: String
        let icon: String
        let group: String
        let includesClipboard: Bool
        let request: ActionRequest
    }

    static func entries(input: ActionInput, manager: PluginManager) -> [Entry] {
        var entries: [Entry] = []
        for plugin in manager.plugins where plugin.info.enabled && plugin.compatibilityIssue(hostVersion: manager.hostVersion) == nil && plugin.info.missingOptions().isEmpty {
            let values = plugin.info.getOptionsValue()
            for action in plugin.actions where action.kind != .keycombo {
                if input.hasAttachment && action.kind != .gpt { continue }
                if action.kind == .gpt && input.kind == nil { continue }
                let options = action.popclip == nil ? values : PopClipAction.optionValues(plugin.info, values: values)
                guard (try? action.prepareContext(input.context, options: options, separatePasteTarget: true)) != nil else { continue }
                entries.append(Entry(id: "plugin:" + action.meta.identifier,
                                     title: PluginTemplate.render(action.meta.title, context: input.context, options: values),
                                     icon: action.meta.icon, group: plugin.info.name, includesClipboard: action.meta.includeClipboard == true,
                                     request: .plugin(plugin, action)))
            }
        }
        return entries
    }
}

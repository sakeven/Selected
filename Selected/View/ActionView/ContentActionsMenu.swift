import SwiftUI

struct ContentActionsMenu: View {
    let input: ActionInput
    let target: ActionTarget
    let onSearch: () -> Void
    @ObservedObject private var manager = PluginManager.shared

    var body: some View {
        Menu {
            Button("Search actions or plugins", systemImage: "magnifyingglass", action: onSearch)
            Divider()
            let entries = ActionCatalog.entries(input: input, manager: manager)
            ForEach(entries) { entry in
                let suffix = entry.includesClipboard ? " · " + String(localized: "Includes clipboard text") : ""
                let title = (entry.group == entry.title ? entry.title : "\(entry.group) · \(entry.title)") + suffix
                Button(title) {
                    ActionCoordinator.perform(entry.request, input: input, target: target)
                }
            }
            if entries.isEmpty { Text("No matching actions") }
        } label: {
            Label("Process content", systemImage: "wand.and.stars")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(AppTheme.accent)
        .help("Process content")
        .accessibilityLabel("Process content")
    }
}

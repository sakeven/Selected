import SwiftUI

struct ContentActionsMenu: View {
    let input: ActionInput
    let target: ActionTarget
    @ObservedObject private var manager = PluginManager.shared

    var body: some View {
        Menu {
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
        .tint(.blue)
        .help("Process content")
        .accessibilityLabel("Process content")
    }
}

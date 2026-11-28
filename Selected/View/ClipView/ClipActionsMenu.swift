import SwiftUI

struct ClipActionsMenu: View {
    @ObservedObject var data: ClipHistoryData
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onShowPlugins: () -> Void
    let onAIRequest: (String, Bool) -> Void

    var body: some View {
        if let text = data.plainText {
            Button("Paste plain text", systemImage: "textformat") {
                ClipWindowManager.shared.pastePlainText(text)
            }
            .keyboardShortcut(.return, modifiers: [.option, .shift])
        }
        ClipActionBar(data: data)
        if let kind = data.aiContentKind() {
            ClipAIMenu(kind: kind, onRequest: onAIRequest)
        }

        ContentActionsMenu(input: ActionInput(clip: data), target: ClipWindowManager.shared.actionTarget ?? ActionTarget(), onSearch: onShowPlugins)

        Divider()

        Button(action: onTogglePin) {
            Label(data.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"), systemImage: "pin")
        }
        .keyboardShortcut("p", modifiers: .command)
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: [.command, .shift])
    }
}

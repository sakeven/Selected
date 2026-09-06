import Defaults
import SwiftUI

struct ClipActionsMenu: View {
    @ObservedObject var data: ClipHistoryData
    @Default(.aiService) private var aiService
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onAIRequest: (String, Bool) -> Void

    var body: some View {
        Button("clip.pasteOriginal", systemImage: "return") {
            ClipService.shared.restore(data, paste: true)
        }
        Button("clip.copy", systemImage: "doc.on.doc") {
            ClipService.shared.restore(data, paste: false)
        }

        if let kind = data.aiContentKind(openAI: aiService == "OpenAI") {
            Divider()
            ClipAIMenu(kind: kind, onRequest: onAIRequest)
        }

        ContentActionsMenu(input: ActionInput(clip: data), target: ClipWindowManager.shared.actionTarget ?? ActionTarget())

        Divider()

        Button(action: onTogglePin) {
            Label(data.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"), systemImage: "pin")
        }
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}

import SwiftUI

struct ClipAIMenu: View {
    let kind: ClipAIContent.Kind
    let onRequest: (String, Bool) -> Void

    var body: some View {
        Menu {
            Button("clip.ai.ask", systemImage: "bubble.left.and.text.bubble.right") {
                onRequest("", false)
            }
            Divider()
            if kind == .text || kind == .document {
                Button("clip.ai.summarize", systemImage: "list.bullet.rectangle") {
                    onRequest(String(localized: "clip.ai.prompt.summarize"), false)
                }
            }
            Button("clip.ai.explain", systemImage: "text.magnifyingglass") {
                onRequest(String(localized: "clip.ai.prompt.explain"), false)
            }
            if kind == .image || kind == .document {
                Button("clip.ai.extract", systemImage: "text.viewfinder") {
                    onRequest(String(localized: "clip.ai.prompt.extract"), false)
                }
            } else if kind == .text {
                Button("clip.ai.polish", systemImage: "pencil.line") {
                    onRequest(String(localized: "clip.ai.prompt.polish"), false)
                }
            }
            if kind != .code && kind != .link {
                Divider()
                Button("clip.ai.translateChinese", systemImage: "character.bubble") {
                    onRequest(String(localized: "clip.ai.prompt.translateChinese"), true)
                }
                Button("clip.ai.translateEnglish", systemImage: "character.bubble") {
                    onRequest(String(localized: "clip.ai.prompt.translateEnglish"), true)
                }
            }
        } label: {
            Label("clip.ai", systemImage: "sparkles")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

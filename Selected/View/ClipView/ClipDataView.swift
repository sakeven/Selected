import SwiftUI
import Defaults

struct ClipDataView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData
    @Default(.aiService) private var aiService
    @State private var showActions = false
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onAIRequest: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(data.contentTypeLabel, systemImage: data.displayKind.symbolName)
                    .labelStyle(.titleAndIcon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onTogglePin) {
                    Label(data.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"), systemImage: data.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(data.isPinned ? Color.accentColor : .secondary)
                }
                .help(data.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"))

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(.secondary)
                }
                .help("Delete")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
            .controlSize(.small)

            ClipPreviewStage(data: data)
                .id(data.MD5())
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colorScheme.clipPreviewFill, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(colorScheme.clipPanelStroke, lineWidth: 1)
                }
                .clipped()

            HStack(spacing: 2) {
                if let kind = data.aiContentKind(openAI: aiService == "OpenAI") {
                    Button("clip.ai.ask", systemImage: "sparkles") {
                        onAIRequest("", false)
                    }

                    if kind == .text || kind == .document {
                        Button("clip.ai.summarize", systemImage: "list.bullet.rectangle") {
                            onAIRequest(String(localized: "clip.ai.prompt.summarize"), false)
                        }
                    } else {
                        Button("clip.ai.explain", systemImage: "text.magnifyingglass") {
                            onAIRequest(String(localized: "clip.ai.prompt.explain"), false)
                        }
                    }

                    if kind == .image || kind == .document {
                        Button("clip.ai.extract", systemImage: "text.viewfinder") {
                            onAIRequest(String(localized: "clip.ai.prompt.extract"), false)
                        }
                    } else if kind == .text {
                        Button("clip.ai.polish.short", systemImage: "pencil.line") {
                            onAIRequest(String(localized: "clip.ai.prompt.polish"), false)
                        }
                    }

                    if kind != .code && kind != .link {
                        Menu {
                            Button("clip.ai.translateChinese") {
                                onAIRequest(String(localized: "clip.ai.prompt.translateChinese"), true)
                            }
                            Button("clip.ai.translateEnglish") {
                                onAIRequest(String(localized: "clip.ai.prompt.translateEnglish"), true)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Label("clip.ai.translate", systemImage: "character.bubble")
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .accessibilityHidden(true)
                            }
                        }
                        .menuStyle(.button)
                        .fixedSize()
                    }
                }

                ClipActionBar(data: data)

                Spacer(minLength: 0)

                Button("Plugins", systemImage: "puzzlepiece.extension") { showActions = true }
                    .help("Process content")
                    .popover(isPresented: $showActions) {
                        ContentActionPicker(input: ActionInput(clip: data)) { request in
                            showActions = false
                            ActionCoordinator.perform(request, input: ActionInput(clip: data), target: ClipWindowManager.shared.actionTarget ?? ActionTarget())
                        }
                    }
            }
            .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
            .controlSize(.small)
            .fixedSize(horizontal: false, vertical: true)
            .padding(4)
            .background(.primary.opacity(0.035), in: .rect(cornerRadius: 10))

            ClipMetadataCard(data: data)

        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 12)
    }
}

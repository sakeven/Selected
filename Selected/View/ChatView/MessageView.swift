import SwiftUI
import MarkdownUI

struct MessageView: View {
    @ObservedObject var message: ResponseMessage
    @State private var showsReasoning = false
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !message.summary.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button { showsReasoning.toggle() } label: {
                        HStack(spacing: 8) {
                            Label("chat.reasoning", systemImage: "brain")
                            Spacer()
                            Image(systemName: showsReasoning ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(showsReasoning ? "chat.expanded" : "chat.collapsed"))
                    if showsReasoning {
                        ChatMarkdownView(markdown: message.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .padding(.top, -4)
                    }
                }
                .background(.primary.opacity(0.025), in: .rect(cornerRadius: 10))
            }

            if !message.tools.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.items, id: \.key) { _, tool in
                        ToolRowView(tool: tool)
                    }
                }
            }

            if !message.previewImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(message.previewImages.indices, id: \.self) { index in
                            if let image = message.previewImages[index] {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 104, height: 104)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .accessibilityLabel(Text("Image"))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !message.files.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(message.files.enumerated()), id: \.offset) { _, file in
                            Label(file.filename, systemImage: "doc.text")
                                .font(.callout)
                                .padding(10)
                                .background(.primary.opacity(0.04), in: .rect(cornerRadius: 10))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !message.message.isEmpty {
                if message.role == .assistant {
                    ChatMarkdownView(markdown: message.message)
                } else {
                    Text(message.message)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(message.status == .failure ? Color.red : .primary)
                }
            }
        }
        .padding(message.role == .assistant ? 0 : 14)
        .frame(maxWidth: message.role == .user ? 540 : .infinity, alignment: .leading)
        .background(background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(message.role == .assistant ? .clear : Color.primary.opacity(0.05), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isCopied = false
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
            Text(LocalizedStringKey(message.role == .user ? "chat.you" : message.role.rawValue))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if message.status == .initial || message.status == .updating {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel(Text("chat.responding"))
            } else if message.status == .failure {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel(Text("failure"))
            }

            Spacer()
            if !message.message.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.message, forType: .string)
                    isCopied = true
                } label: {
                    Label(isCopied ? "chat.copied" : "chat.copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .frame(width: 26, height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(isCopied ? "chat.copied" : "chat.copy")

                if message.role == .assistant {
                    Button {
                        Task { await TTSManager.speak(MarkdownContent(message.message).renderPlainText(), view: false) }
                    } label: {
                        Label("chat.readAloud", systemImage: "speaker.wave.2")
                            .labelStyle(.iconOnly)
                            .frame(width: 26, height: 26)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help("chat.readAloud")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var background: Color {
        switch message.role {
        case .assistant: .clear
        case .user: .primary.opacity(0.045)
        case .system: message.status == .failure ? .red.opacity(0.06) : .primary.opacity(0.025)
        }
    }
}

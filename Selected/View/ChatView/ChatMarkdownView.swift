import SwiftUI
import Textual

struct ChatMarkdownView: View {
    let markdown: String

    var body: some View {
        StructuredText(markdown: markdown, syntaxExtensions: [.math])
            .textual.headingStyle(ChatHeadingStyle())
            .textual.paragraphStyle(ChatParagraphStyle())
            .textual.codeBlockStyle(ChatCodeBlockStyle())
            .textual.structuredTextStyle(.gitHub)
            .textual.textSelection(.enabled)
            .textual.overflowMode(.scroll)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatHeadingStyle: StructuredText.HeadingStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.fontScale(configuration.headingLevel == 1 ? 1.35 : configuration.headingLevel == 2 ? 1.2 : 1.08)
            .fontWeight(.semibold)
            .textual.lineSpacing(.fontScaled(0.18))
            .textual.blockSpacing(.init(top: 20, bottom: 10))
    }
}

private struct ChatParagraphStyle: StructuredText.ParagraphStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.lineSpacing(.fontScaled(0.3))
            .textual.blockSpacing(.init(top: 0, bottom: 12))
    }
}

private struct ChatCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        ChatCodeBlock(configuration: configuration)
            .textual.blockSpacing(.init(top: 0, bottom: 14))
    }
}

private struct ChatCodeBlock: View {
    let configuration: StructuredText.CodeBlockStyleConfiguration
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(configuration.languageHint ?? String(localized: "chat.code"))
                    .font(.caption.monospaced())
                Spacer()
                Button {
                    configuration.codeBlock.copyToPasteboard()
                    isCopied = true
                } label: {
                    Label(isCopied ? "chat.copied" : "chat.copyCode", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .padding(.vertical, 5)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(.primary.opacity(0.025))

            Divider().opacity(0.5)

            Overflow {
                configuration.label
                    .monospaced()
                    .textual.fontScale(0.9)
                    .textual.lineSpacing(.fontScaled(0.25))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
            }
        }
        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 12))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        }
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isCopied = false
        }
    }
}

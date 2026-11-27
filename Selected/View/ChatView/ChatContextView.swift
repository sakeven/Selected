import SwiftUI

struct ChatContextView: View {
    let ctx: ChatContext
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !ctx.text.isEmpty || !ctx.images.isEmpty || !ctx.files.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button { isExpanded.toggle() } label: {
                        HStack(spacing: 10) {
                            if ctx.files.isEmpty {
                                Image(systemName: "text.quote")
                                    .accessibilityHidden(true)
                            } else {
                                Image("ClipboardFile")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(ClipDisplayKind.file.tint)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("chat.context")
                                    .font(.caption.weight(.medium))
                                Text(ctx.text.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(isExpanded ? "chat.expanded" : "chat.collapsed"))

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            if !ctx.images.isEmpty || !ctx.files.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(ctx.images.enumerated()), id: \.offset) { _, data in
                                            if let image = NSImage(data: data) {
                                                Image(nsImage: image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 88, height: 88)
                                                    .clipShape(.rect(cornerRadius: 8))
                                                    .accessibilityLabel(Text("Image"))
                                            }
                                        }
                                        ForEach(Array(ctx.files.enumerated()), id: \.offset) { _, file in
                                            Label {
                                                Text(file.filename)
                                            } icon: {
                                                Image("ClipboardFile")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 18, height: 18)
                                                    .foregroundStyle(ClipDisplayKind.file.tint)
                                                    .accessibilityHidden(true)
                                            }
                                            .font(.callout)
                                            .padding(10)
                                            .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                            Text(ctx.text)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let url = URL(string: ctx.webPageURL), !ctx.webPageURL.isEmpty {
                                Link(destination: url) {
                                    Label("chat.openSource", systemImage: "arrow.up.right")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(12)
                        .padding(.top, -4)
                    }
                }
                .background(AppTheme.surface, in: .rect(cornerRadius: AppTheme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).strokeBorder(AppTheme.border, lineWidth: 1))
            }

            if let request = ctx.request, !request.isEmpty {
                Text(request)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: 540, alignment: .leading)
                    .background(AppTheme.selection, in: .rect(cornerRadius: AppTheme.cardRadius))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

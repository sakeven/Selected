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
                            Image(systemName: ctx.files.isEmpty ? "text.quote" : "doc")
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
                                            Label(file.filename, systemImage: "doc.fill")
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
                .background(.primary.opacity(0.025), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06), lineWidth: 1))
            }

            if let request = ctx.request, !request.isEmpty {
                Text(request)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: 540, alignment: .leading)
                    .background(.primary.opacity(0.045), in: .rect(cornerRadius: 16))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

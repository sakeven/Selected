import SwiftUI

struct ToolRowView: View {
    let tool: AIToolCall
    @State private var isExpanded = false

    private var hasDetails: Bool {
        !tool.ret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !(tool.arguments?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        || !(tool.command?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        || !(tool.workdir?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        || !tool.uniqueSourceLinks.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if hasDetails {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        cardLabel
                    }
                    .buttonStyle(.plain)
                } else {
                    cardLabel
                }
            }

            if isExpanded && hasDetails {
                VStack(alignment: .leading, spacing: 12) {
                    if !tool.uniqueSourceLinks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            detailTitle("Sources")
                            ForEach(tool.uniqueSourceLinks) { source in
                                Link(destination: URL(string: source.url)!) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.title.isEmpty ? source.url : source.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(source.url)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let command = tool.command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailBlock(title: "Command", text: command, monospaced: true)
                    }

                    if let workdir = tool.workdir, !workdir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailBlock(title: "Workdir", text: workdir, monospaced: true)
                    }

                    if let arguments = tool.arguments, !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailBlock(title: "Arguments", text: arguments, monospaced: true)
                    }

                    if !tool.ret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailBlock(title: "Output", text: tool.ret, monospaced: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var cardLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: tool.iconSystemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                if hasDetails && !isExpanded {
                    Text(tool.compactResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)

            statusView

            if hasDetails {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func detailBlock(title: String, text: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            detailTitle(title)
            Text(text)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch tool.status {
            case .calling:
                ProgressView()
                    .controlSize(.mini)
                    .tint(statusColor)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
        }
    }

    private var statusText: String {
        switch tool.status {
            case .calling: return String(format: NSLocalizedString("calling…", comment: ""))
            case .success: return String(format: NSLocalizedString("success", comment: ""))
            case .failure: return String(format: NSLocalizedString("failure", comment: ""))
        }
    }

    private var statusColor: Color {
        switch tool.status {
            case .calling: return .blue
            case .success: return .green
            case .failure: return .red
        }
    }
}

private extension AIToolCall {
    var displayName: String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var compactResult: String {
        ret
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var uniqueSourceLinks: [AIToolSourceLink] {
        var seen = Set<String>()
        return sourceLinks.filter { link in
            seen.insert(link.id).inserted
        }
    }

    var iconSystemName: String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("search") || lowercasedName.contains("crawler") || lowercasedName.contains("web") {
            return "globe"
        }
        if lowercasedName.contains("image") || lowercasedName.contains("photo") || lowercasedName.contains("svg") {
            return "photo"
        }
        if lowercasedName.contains("speak") || lowercasedName.contains("tts") || lowercasedName.contains("audio") {
            return "speaker.wave.2"
        }
        if lowercasedName.contains("file") || lowercasedName.contains("read") || lowercasedName.contains("write") {
            return "doc.text"
        }
        return "hammer"
    }
}



#Preview {
    ToolRowView(tool: AIToolCall(name: "local_crawler", ret: "", status: .success, arguments: nil, command: nil, workdir: nil, sourceLinks: []))
}

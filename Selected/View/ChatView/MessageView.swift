//
//  MessageView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Textual

struct MessageView: View {
    @ObservedObject var message: ResponseMessage

    @State private var spinning = false

    var body: some View {
        bubble
            .frame(maxWidth: .infinity, alignment: bubbleAlignment)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            messageContent
        }
        .padding(18)
        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
        .background(bubbleFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(bubbleStrokeColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.role {
            case .system:
                Text(message.message)
                    .foregroundStyle(message.status == .failure ? .red : .primary)
                    .textSelection(.enabled)
            case .user:
                if !message.previewImages.isEmpty {
                    previewHeader
                }

                Text(message.message)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            case .assistant:
                if message.summary != "" {
                    StructuredText(markdown: message.summary, patternOptions: .init(mathExpressions: true))
                        .textual.textSelection(.enabled)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if !message.tools.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tools", systemImage: "hammer.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(message.items, id: \.key) { key, tool in
                            ToolRowView(tool: tool)
                        }
                    }
                }

                if !message.previewImages.isEmpty {
                    previewHeader
                }

                StructuredText(markdown: message.message, patternOptions: .init(mathExpressions: true))
                    .textual.fontScale(1.1)
                    .textual.textSelection(.enabled)
                    .textual.structuredTextStyle(.gitHub)
                    .textual.overflowMode(.wrap)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(message.role.rawValue))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(roleTint)

                statusIcon
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(roleTint.opacity(0.12), in: Capsule())

            Spacer(minLength: 0)

            if message.role == .assistant, !message.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messageActionButton(systemImage: "doc.on.doc") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(message.message, forType: .string)
                }

                messageActionButton(systemImage: "speaker.wave.2.fill") {
                    Task {
                        await TTSManager.speak(MarkdownContent(message.message).renderPlainText(), view: false)
                    }
                }
            }
        }
    }

    private var previewHeader: some View {
        Group {
            if message.previewImages.count < 5 {
                HStack(spacing: 8) {
                    ForEach(message.previewImages.indices, id: \.self ) { id in
                        imagePreview(message.previewImages[id])
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.previewImages.indices, id: \.self ) { id in
                            imagePreview(message.previewImages[id])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func imagePreview(_ nsImage: NSImage?) -> some View {
        if let nsImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Color.gray.frame(width: 64, height: 64)
        }
    }

    private func messageActionButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if message.role == .assistant {
            switch message.status {
                case .initial, .updating:
                    Image(systemName: "arrow.2.circlepath")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
                        .onAppear { spinning = true }
                case .finished:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .failure:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
            }
        } else if message.role == .system && message.status == .failure {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var roleTint: Color {
        switch message.role {
            case .assistant: return .accentColor
            case .user: return .secondary
            case .system: return message.status == .failure ? .red : .secondary
        }
    }

    private var bubbleFill: Color {
        switch message.role {
            case .assistant:
                return Color(nsColor: .textBackgroundColor).opacity(0.92)
            case .user:
                return Color.accentColor.opacity(0.10)
            case .system:
                if message.status == .failure {
                    return Color.red.opacity(0.08)
                }
                return Color(nsColor: .controlBackgroundColor).opacity(0.75)
        }
    }

    private var bubbleStrokeColor: Color {
        switch message.role {
            case .assistant:
                return Color.primary.opacity(0.05)
            case .user:
                return Color.accentColor.opacity(0.12)
            case .system:
                if message.status == .failure {
                    return Color.red.opacity(0.14)
                }
                return Color.primary.opacity(0.05)
        }
    }

    private var bubbleAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleMaxWidth: CGFloat {
        switch message.role {
            case .assistant, .system:
                return 620
            case .user:
                return 520
        }
    }
}

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
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

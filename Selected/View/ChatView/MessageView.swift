//
//  MessageView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Highlightr

struct MessageView: View {
    @ObservedObject var message: ResponseMessage

    @Environment(\.colorScheme) private var colorScheme


    @State private var rotation: Double = 0
    @State private var animationTimer: Timer? = nil
    @State private var spinning = false

    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(LocalizedStringKey(message.role.rawValue))
                    .foregroundStyle(.blue.gradient).font(.headline)
                if message.role == .assistant {
                    switch message.status {
                        case .initial, .updating:
                            Image(systemName: "arrow.2.circlepath")
                                .foregroundStyle(.orange)
                                .rotationEffect(.degrees(spinning ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
                                .onAppear { spinning = true }
                        case .finished:
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        default:
                            EmptyView()
                    }
                } else if message.role == .system && message.status == .failure {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                Spacer()
                if message.role == .assistant {
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(message.message, forType: .string)
                    }, label: {
                        Image(systemName: "doc.on.clipboard.fill")
                    })
                    .foregroundColor(Color.white)
                    .cornerRadius(5)
                    Button {
                        Task {
                            await TTSManager.speak(MarkdownContent(message.message).renderPlainText(), view: false)
                        }
                    } label: {
                        Image(systemName: "play.circle")
                    }.foregroundColor(Color.white)
                        .cornerRadius(5)
                }
            }.frame(height: 20).padding(.trailing, 30.0)


            if message.role == .system {
                if message.status == .failure {
                    Text(message.message).foregroundStyle(.red)
                        .padding(.leading, 20.0)
                        .padding(.trailing, 40.0)
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                } else {
                    Text(message.message)
                        .padding(.leading, 20.0)
                        .padding(.trailing, 40.0)
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                }
            } else {
                if message.summary != "" {
                    MarkdownWithLateXView(markdownString: $message.summary).font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .padding(.leading, 20.0)
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.trailing, 40.0)
                }
                if !message.tools.isEmpty {
                    Label {
                        Text("Tool Call List")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "hammer.fill")
                    }
                    .padding(.bottom, 4)
                    ForEach(message.items, id: \.key) { key, tool in
                        ToolRowView(tool: tool)
                            .padding(.top, 4)
                            .padding(.leading, 10)
                    }
                    Divider().padding(.trailing, 40.0)
                }
                if !message.images.isEmpty {
                    previewHeader.padding(.leading, 20.0)
                }
                MarkdownWithLateXView(markdownString: $message.message)
                    .padding(.leading, 20.0)
                    .padding(.trailing, 40.0)
                    .padding(.top, 5)
                    .padding(.bottom, 20)
            }
        }.frame(width: 750).textSelection(.enabled)
    }

    private var previewHeader: some View {
        if message.images.count < 5 {
            AnyView(HStack(spacing: 8) {
                ForEach(message.images.indices, id: \.self ) { id in
                    if let nsImage = NSImage(data: message.images[id]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Color.gray.frame(width: 64, height: 64)
                    }
                }
            })
        } else {
            AnyView(ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(message.images.indices, id: \.self ) { id in
                        if let nsImage = NSImage(data: message.images[id]) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Color.gray.frame(width: 64, height: 64)
                        }
                    }
                }
            })
        }
    }

    private var codeTheme: CodeTheme {
        switch self.colorScheme {
            case .dark:
                return .dark
            default:
                return .light
        }
    }
}

struct ToolRowView: View {
    let tool: AIToolCall

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusView                // 左边状态图标/进度

            VStack(alignment: .leading, spacing: 4) {
                // 工具名称 + 状态文字
                HStack(spacing: 6) {
                    Text(tool.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                // 如果已经成功/失败，并且有输出，则展示返回内容
                if tool.status != .calling {   // 仅结束后展示
                    Text(tool.ret)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)              // 视情况调
                        .textSelection(.enabled)   // macOS：方便复制
                }
            }

            Spacer()
        }
    }

    // MARK: - 子视图 & 计算属性

    @ViewBuilder
    private var statusView: some View {
        switch tool.status {
            case .calling:
                // 一个小的进度圈，表示正在调用
                ProgressView()
                    .controlSize(.small)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure:
                Image(systemName: "xmark.octagon.fill")
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



#Preview {
    ToolRowView(tool: AIToolCall(name: "local_crawler", ret: "", status: .success))
}


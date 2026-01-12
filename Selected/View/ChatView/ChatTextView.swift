//
//  ChatTextView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Defaults
import Combine

struct ChatTextView: View {
    let ctx: ChatContext

    @ObservedObject var viewModel: MessageViewModel
    @EnvironmentObject var pinned: PinnedModel
    @State private var task: Task<Void, Never>? = nil
    @State private var isCollapsed: Bool = false

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedBubble(isCollapsed: $isCollapsed)
            } else {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading){
                        HStack {
                            if ctx.bundleID != "" {
                                getIcon(ctx.bundleID)
                                Text(getAppName(ctx.bundleID))
                            }
                            Spacer()
                            Button {
                                pinned.pinned = !pinned.pinned
                            } label: {
                                if pinned.pinned {
                                    Text(String(localized: "chat.unpin"))
                                } else {
                                    Text(String(localized: "chat.pin"))
                                }
                            }
                            Button {
                                withAnimation {
                                    isCollapsed = true
                                    pinned.pinned = true
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }.padding(.bottom, 10)

                        Text(ctx.text.trimmingCharacters(in: .whitespacesAndNewlines)).font(.custom( "UbuntuMonoNFM", size: 16)).foregroundColor(.gray).lineLimit(1)
                            .frame(alignment: .leading).padding(.leading, 10).copyable([ctx.text]).textSelection(.enabled)
                        if ctx.webPageURL != "" {
                            HStack {
                                Spacer()
                                Link(destination: URL(string: ctx.webPageURL)!, label: {
                                    Image(systemName: "globe")
                                })
                            }
                        }
                    }.padding()

                    ScrollViewReader { scrollViewProxy in
                        List {
                            ForEach($viewModel.messages) { $message in
                                MessageView(message: message)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM")
                        }.scrollContentBackground(.hidden)
                            .listStyle(.inset)
                            .frame(width: 750, height: 400).onChange(of: viewModel.messages) { _ in
                                scrollToBottom(scrollViewProxy)
                            }.onReceive(lastMessageWillChangePublisher) { _ in
                                scrollViewProxy.scrollTo("BOTTOM", anchor: .bottom)
                            }
                    }

                    Spacer(minLength: 0)

                    ZStack(alignment: .bottom) {
                        Color.clear
                        ChatInputView(viewModel: viewModel, onCancel: {
                            task?.cancel()
                        })
                        .frame(minHeight: 100)
                        .padding(.leading, 20.0)
                        .padding(.trailing, 20.0)
                        .padding(.bottom, 10)
                        .ignoresSafeArea(edges: .bottom)
                    }
                }.frame(minHeight: 650)
                    .frame(width: 750,  alignment: .top)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

            }
        }.onAppear {
            task = Task{
                await viewModel.fetchMessages(ctx: ctx)
            }
        }.onDisappear(){
            task?.cancel()
        }
    }

    private func getAppName(_ bundleID: String) -> String {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    private func getIcon(_ bundleID: String) -> some View {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return AnyView(
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30)
        )
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private var lastMessageWillChangePublisher: AnyPublisher<Void, Never> {
        guard let last = viewModel.messages.last else {
            return Empty().eraseToAnyPublisher()
        }
        return last.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}


struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class DraggableView: NSView {
    override func mouseDown(with event: NSEvent) {
        // 鼠标按下就允许拖动窗口
        window?.performDrag(with: event)
    }
}

private struct FocusEffectDisabler: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled(true)
        } else {
            content
        }
    }
}

struct CollapsedBubble: View {
    @Binding var isCollapsed: Bool

    var body: some View {
        ZStack {
            WindowDragArea()
                .frame(width: 44, height: 44)
                .contentShape(Circle())          // 尽量让命中更“圆”
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .mask(Circle())
                        .compositingGroup()
                }

            Button {
                withAnimation { isCollapsed = false }
            } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 18))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .modifier(FocusEffectDisabler())
        }
    }
}

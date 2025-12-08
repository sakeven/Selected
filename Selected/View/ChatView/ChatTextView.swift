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


struct ChatTextView: View {
    let ctx: ChatContext

    @ObservedObject var viewModel: MessageViewModel
    @EnvironmentObject var pinned: PinnedModel
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading){
                if ctx.bundleID != "" {
                    HStack {
                        getIcon(ctx.bundleID)
                        Text(getAppName(ctx.bundleID))
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
                    }.padding(.bottom, 10)
                }
                Text(ctx.text.trimmingCharacters(in: .whitespacesAndNewlines)).font(.custom( "UbuntuMonoNFM", size: 14)).foregroundColor(.gray).lineLimit(1)
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
                List($viewModel.messages) { $message in
                    MessageView(message: message).id(message.id)
                }.scrollContentBackground(.hidden)
                    .listStyle(.inset)
                    .frame(width: 750, height: 400).onAppear {
                        task = Task{
                            await viewModel.fetchMessages(ctx: ctx)
                        }
                    }.onChange(of: viewModel.messages) { _ in
                        if let lastItemIndex = $viewModel.messages.last?.id {
                            // Scroll to the last item
                            withAnimation {
                                scrollViewProxy.scrollTo(lastItemIndex, anchor: .bottom)
                            }
                        }
                    }
            }
            ChatInputView(viewModel: viewModel, onCancel: {
                task?.cancel()
                print("cancel")
            })
                .frame(minHeight: 50)
                .padding(.leading, 20.0)
                .padding(.trailing, 20.0)
                .padding(.bottom, 10)
        }.frame(width: 750)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .onDisappear(){
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
}

struct ChatInputView: View {
    var viewModel: MessageViewModel
    @State private var newText: String = ""
    @State private var task: Task<Void, Never>? = nil

    var onCancel: (() -> Void)?

    var body: some View {
        Button {
            cancel()
        } label: {
            Text("cancel")
        }
        if #available(macOS 14.0, *) {
            ZStack(alignment: .leading){
                if newText.isEmpty {
                    Text("Press cmd+enter to send new message")
                        .disabled(true)
                        .padding(4)
                }
                TextEditor(text: $newText).onKeyPress(.return, phases: .down) {keyPress in
                    if !keyPress.modifiers.contains(.command) {
                        return .ignored
                    }
                    submitMessage()
                    return .handled
                }
                .opacity(self.newText.isEmpty ? 0.25 : 1)
                .padding(10)
            } .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onDisappear(){
                    task?.cancel()
                }
        } else {
            // Fallback on earlier versions
            TextField("Press enter to send new message", text: $newText, axis: .vertical)
                .lineLimit(3...)
                .textFieldStyle(.plain)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()
                .onSubmit {
                    submitMessage()
                }.onDisappear(){
                    task?.cancel()
                }
        }
    }

    func cancel() {
        task?.cancel()
        if let onCancel = onCancel {
            onCancel()
        }
    }

    func submitMessage(){
        let message = newText
        newText = ""
        task = Task {
            await viewModel.submit(message: message)
        }
    }
}

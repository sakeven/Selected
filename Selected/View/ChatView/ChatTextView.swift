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
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        VStack(alignment: .leading) {
            ScrollViewReader { scrollViewProxy in
                List($viewModel.messages) { $message in
                    MessageView(message: message).id(message.id)
                }.scrollContentBackground(.hidden)
                    .listStyle(.inset)
                    .frame(width: 750, height: 400).task {
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

            }.padding(.top, 20)
            ChatInputView(viewModel: viewModel)
                .frame(minHeight: 50)
                .padding(.leading, 20.0)
                .padding(.trailing, 20.0)
                .padding(.bottom, 10)
        }.frame(width: 750).onDisappear(){
            task?.cancel()
        }
    }
}

struct ChatInputView: View {
    var viewModel: MessageViewModel
    @State private var newText: String = ""
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        if #available(macOS 14.0, *), !Defaults[.useTextFieldInChat]  {
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
                .padding(4)
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

    func submitMessage(){
        let message = newText
        newText = ""
        DispatchQueue.global(qos: .background).async {
            task = Task {
                await viewModel.submit(message: message)
            }
        }
    }
}

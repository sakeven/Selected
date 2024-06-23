//
//  ContentView.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import SwiftUI
import MarkdownUI
import Highlightr

struct TranslationView: View {
    var text: String
    @State var transText: String = "..."
    @State private var hasRep = false
    var to: String = "cn"

    @Environment(\.colorScheme) private var colorScheme
    var highlighter = CustomCodeSyntaxHighlighter()

    @State private var word: Word?

    var body: some View {
        VStack(alignment: .leading) {
            if let w = word {
                Label {
                    Text("[\(w.phonetic)]")
                } icon: {
                    Text("phonetic")
                }.padding(.top, 20).padding(.leading, 20)
                if w.exchange != "" {
                    Label {
                        Text(w.exchange)
                    } icon: {
                        Text("exchange")
                    }.padding(.leading, 20)
                }
                Divider()
            }
            ScrollView(.vertical){
                Markdown(self.transText)
                    .markdownBlockStyle(\.codeBlock, body: {label in
                        // wrap long lines
                        highlighter.setTheme(theme: codeTheme).highlightCode(label.content, language: label.language)
                            .padding()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .markdownMargin(top: .em(1), bottom: .em(1))
                    })
                    .padding(.leading, 20.0)
                    .padding(.trailing, 20.0)
                    .padding(.top, 20)
                    .frame(width: 550, alignment: .leading)
                    .task {
                        if isPreview {
                            return
                        }
                        if isWord(str: text) {
                            word = try! StarDict.shared.query(word: text)
                        }
                        await Translation(toLanguage: to).translate(content: text) { content in
                            if !hasRep {
                                transText = content
                                hasRep = true
                            } else {
                                transText = transText + content
                            }
                        }
                    }
            }.frame(width: 550, height: 300)
            Divider()
            HStack{
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let painText  = MarkdownContent(self.transText).renderPlainText()
                    pasteboard.setString(painText, forType: .string)
                }, label: {
                    Image(systemName: "doc.on.clipboard.fill")
                })
                .foregroundColor(Color.white)
                .cornerRadius(5)
                Button {
                    Task{
                        await speak(MarkdownContent(self.transText).renderPlainText())
                    }
                } label: {
                    Image(systemName: "play.circle")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }.frame(width: 550, height: 30).padding(.bottom, 10)
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

import NetworkImage


/// The default image provider, which loads images from the network.
public struct MarkdownImageProvider: ImageProvider {
    public func makeImage(url: URL?) -> some View {
        NetworkImage(url: url) { state in
            switch state {
                case .empty, .failure:
                    Color.clear
                        .frame(width: 0, height: 0)
                case .success(let image, _):
                    //                    ResizeToFit(idealSize: idealSize) {
                    image.resizable().aspectRatio(contentMode: .fit).frame(width: 510)
                    //                    }
            }
        }
    }
}


class MessageViewModel: ObservableObject {
    @Published var messages: [ResponseMessage] = []
    var chatService: AIChatService

    init(chatService: AIChatService) {
        self.chatService = chatService
        self.messages.append(ResponseMessage(message: "waiting", role: "none"))
    }


    func fetchMessages(content: String, options: [String:String]) async -> Void{
        await chatService.chat(content: content, options: options) { [weak self]  index, message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.messages.count < index+1 {
                    self.messages.append(ResponseMessage(message: "", role: ""))
                }
                if message.new {
                    self.messages[index].message = message.message
                } else {
                    self.messages[index].message += message.message
                }
                NSLog("\(index) \(self.messages[index].message)")
                self.messages[index].role = message.role
            }
        }
    }
}


struct MessageView: View {
    let message: ResponseMessage
    
    @Environment(\.colorScheme) private var colorScheme
    var highlighter = CustomCodeSyntaxHighlighter()

    var body: some View {
        VStack(alignment: .leading){
            Text(LocalizedStringKey(message.role))
                .foregroundStyle(.blue.gradient).font(.headline)

            Markdown(message.message)
                .markdownBlockStyle(\.codeBlock) {
                    codeBlock($0)
                }
                .frame(width: 480, alignment: .leading)
                .padding(.leading, 20.0)
                .padding(.trailing, 20.0)
                .padding(.top, 5)
                .padding(.bottom, 20)
        }
    }



    @ViewBuilder
    private func codeBlock(_ configuration: CodeBlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(configuration.language ?? "plain text")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()

                Image(systemName: "clipboard")
                    .onTapGesture {
                        copyToClipboard(configuration.content)
                    }
            }
            .padding(.horizontal, 5)

            Divider()

            // wrap long lines
            highlighter.setTheme(theme: codeTheme).highlightCode(configuration.content, language: configuration.language)
                .relativeLineSpacing(.em(0.5))
                .padding(5)
                .markdownMargin(top: .em(1), bottom: .em(1))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .markdownMargin(top: .zero, bottom: .em(0.8))
    }



    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
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


struct ChatTextView: View {
    var text: String
    var options: [String: String]
    @ObservedObject var viewModel: MessageViewModel
    @State private var hasRep = false

    var body: some View {
        VStack(alignment: .leading) {
            List(viewModel.messages) { message in
                MessageView(message: message)
            }.scrollContentBackground(.hidden)
                .listStyle(.inset)
            .frame(width: 550, height: 300).task {
                    await viewModel.fetchMessages(content: text, options: options)
                }
            Divider()
            HStack{
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let painText = MarkdownContent(viewModel.messages[0].message).renderPlainText()
                    pasteboard.setString(painText, forType: .string)
                }, label: {
                    Image(systemName: "doc.on.clipboard.fill")
                })
                .foregroundColor(Color.white)
                .cornerRadius(5)
                Button {
                    Task {
                        await speak(MarkdownContent(viewModel.messages[0].message).renderPlainText())
                    }
                } label: {
                    Image(systemName: "play.circle")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }.frame(width: 550, height: 30)
        }
    }
}

var isPreview: Bool {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

#Preview {
    TranslationView(text: "单词；语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。", transText: """
### Word

- **意思1：** 单词；语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。

  **例句：** He asked me to spell the word "responsibility".

- **意思1：** 单词；语言的基本单位，用来表达概念、事物或动作。

  **例句：** He asked me to spell the word "responsibility".

- **意思1：** 单词；语言的基本单位，用来表达概念、事物或动作。

  **例句：** He asked me to spell the word "responsibility".

- **意思1：** 单词；语言的基本单位，用来表达概念、事物或动作。

  **例句：** He asked me to spell the word "responsibility".

- **意思2：** 单词；语言的基本单位，用来表达概念、事物或动作。

  **例句：** He asked me to spell the word "responsibility".
"""
    )
}


struct PopResultView: View {
    var text: String

    var body: some View {
        VStack(alignment: .center){
            Text(text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 10).padding(.leading, 10).padding(.trailing, 10)
                .background(.gray).cornerRadius(5).fixedSize()
        }
    }
}

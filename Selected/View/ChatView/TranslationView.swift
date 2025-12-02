//
//  TranslationView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI

struct TranslationView: View {
    var text: String
    @State var transText: String = "..."

    @State private var hasRep = false
    @State private var showText = false
    var to: String = "cn"

    @EnvironmentObject var pinned: PinnedModel
    @Environment(\.colorScheme) private var colorScheme
    var highlighter = CustomCodeSyntaxHighlighter()

    @State private var word: Word?

    var body: some View {
        VStack(alignment: .leading) {
            header
            Divider()
            if word != nil {
                wordView
                Divider()
            }

            if !hasRep {
                loadingView
            } else {
                tranlationView
            }
            Spacer()
        }.frame(width: 320, height: 400)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
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
    }

    private var orinialText: some View{
            Text(text)
            .textSelection(.enabled)
            .fontWeight(.light)
            .padding(.horizontal, 20.0)
    }

    @State private var isCopied = false
    private var header: some View{
        HStack{
            Text("Translation").font(.title).bold()
            Spacer()

            if !isWord(str: text){
                Button {
                    showText = !showText
                } label: {
                    Image(systemName: showText ? "text.page.slash" : "text.page")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }

            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let painText  = MarkdownContent(self.transText).renderPlainText()
                pasteboard.setString(painText, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now()+0.2){
                    isCopied = false
                }
            }, label: {
                Image(systemName: "doc.on.clipboard.fill").foregroundColor(isCopied ? .green: .primary)
            })
            .foregroundColor(Color.white)
            .cornerRadius(5)

            Button {
                Task{
                    await TTSManager.speak(self.text, view: false)
                }
            } label: {
                Image(systemName: "play.circle")
            }.foregroundColor(Color.white)
                .cornerRadius(5)
            Button {
                pinned.pinned = !pinned.pinned
            } label: {
                if pinned.pinned {
                    Text("unpin")
                } else {
                    Text("pin")
                }
            }
        }
        .padding([.horizontal, .top], 12)
        .padding(.bottom, 8)
    }

    private var wordView: some View{
        VStack(alignment: .leading) {
            Label {
                Text("[\(word!.phonetic)]")
            } icon: {
                Text("phonetic")
            }
            if word!.exchange != "" {
                Label {
                    Text(word!.exchange)
                } icon: {
                    Text("exchange")
                }
            }
        }.padding(.leading, 20)
    }

    private var tranlationView: some View{
        ScrollView(.vertical){
            if !isWord(str: text) && showText {
                orinialText
                Divider()
            }

            Markdown(self.transText)
                .markdownBlockStyle(\.codeBlock, body: {label in
                    // wrap long lines
                    highlighter.setTheme(theme: codeTheme).highlightCode(label.content, language: label.language)
                        .padding()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .markdownMargin(top: .em(1), bottom: .em(1))
                })
                .textSelection(.enabled)
                .padding(.top, 0)
                .padding([.horizontal, .bottom], 20.0)
                .frame(alignment: .leading)
        }
    }

    private var loadingView: some View{
        HStack(spacing: 0) {
            ProgressView().scaleEffect(0.8)
            Text("in translating")
                .font(.system(size: 14))
        }.padding(.leading, 20)
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

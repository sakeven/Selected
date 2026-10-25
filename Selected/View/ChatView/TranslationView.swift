//
//  TranslationView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Textual

struct TranslationView: View {
    var text: String
    @State var transText: String = "..."

    @State private var hasRep = false
    @State private var showText = false
    var to: String = "cn"

    @EnvironmentObject var pinned: PinnedModel

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
            .modifier(AppPanel())
            .task {
                if isPreview {
                    return
                }
                if isWord(str: text) {
                    word = try! StarDict.shared.query(word: text)
                }
                await Translation(toLanguage: to).translate(content: text) { content in
                    guard !Task.isCancelled else { return }
                    if !hasRep {
                        transText = content
                        hasRep = true
                    } else {
                        transText = transText + content
                    }
                }
            }
            .onDisappear(){
                logger.debug("disappear")
            }
    }

    private var orinialText: some View{
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)))
            .textSelection(.enabled)
            .fontWeight(.light)
            .padding(.horizontal, 20.0)
    }

    @State private var isCopied = false
    private var header: some View {
        HStack(spacing: 4) {
            Text("Translation").font(.title3.weight(.semibold))
            Spacer(minLength: 4)
            if !isWord(str: text) {
                Button("Original content", systemImage: "text.quote") { showText.toggle() }
                    .buttonStyle(AppIconButtonStyle(isSelected: showText))
                    .help("Original content")
            }
            Button(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc") {
                copyText(MarkdownContent(transText).renderPlainText())
                isCopied = true
            }
            .disabled(!hasRep)
            .help("Copy")
            Button("chat.readAloud", systemImage: "speaker.wave.2") {
                Task { await TTSManager.speak(text, view: false) }
            }
            .help("chat.readAloud")
            Button(pinned.pinned ? "chat.unpin" : "chat.pin", systemImage: pinned.pinned ? "pin.fill" : "pin") {
                pinned.pinned.toggle()
            }
            .buttonStyle(AppIconButtonStyle(isSelected: pinned.pinned))
            .help(pinned.pinned ? "chat.unpin" : "chat.pin")
        }
        .buttonStyle(AppIconButtonStyle())
        .padding(16)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isCopied = false
        }
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

            StructuredText(markdown: transText)
                .textual.fontScale(1.1)
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .textual.overflowMode(.wrap)
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

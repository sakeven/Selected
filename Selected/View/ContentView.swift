//
//  ContentView.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import SwiftUI
import MarkdownUI
import Splash

struct SelectedTextView: View {
    @State var text: String
    @State var transText: String = "请求中..."
    @State private var hasRep = false
    var to: String = "cn"
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView{
                VStack(alignment: .leading) {
                    Markdown(self.transText).markdownMargin(bottom: 10)
                        .frame(minHeight: 100)
                        .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: 16))))
                        .padding(.leading, 10.0)
                        .padding(.trailing, 10.0)
                        .frame(minHeight: 0, maxHeight: .infinity)
                }.task {
                    if isPreview {
                        return
                    }
                    await Translation(toLanguage: to).translate(content: text) { content in
                        if !hasRep {
                            transText = ""
                            hasRep = true
                        }
                        transText = transText + content
                    }
                }
            }.padding(.top, 10)
            
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
                    speak(text: MarkdownContent(self.transText).renderPlainText())
                } label: {
                    Image(systemName: "play.circle")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }.padding(.leading, 10)
        }.frame(width: 400)
            .frame(minHeight: 400) // TODO: minHeight 可以通过翻译后的行数估计，与 400 取一个最小值。
            .frame(maxHeight: 500)
    }
}


struct ChatTextView: View {
    @State var text: String
    var prompt: String
    @State var respText: String = "请求中..."
    @State private var hasRep = false
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView{
                VStack(alignment: .leading) {
                    Markdown(self.respText).markdownMargin(bottom: 10)
                        .frame(minHeight: 100)
                        .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: 16))))
                        .padding(.leading, 10.0)
                        .padding(.trailing, 10.0)
                        .frame(minHeight: 0, maxHeight: .infinity)
                }.task {
                    if isPreview {
                        return
                    }
                    await ChatService(prompt: prompt).chat(content: text) { content in
                        if !hasRep {
                            respText = ""
                            hasRep = true
                        }
                        respText = respText + content
                    }
                }
            }.padding(.top, 10)
            
            HStack{
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let painText  = MarkdownContent(self.respText).renderPlainText()
                    pasteboard.setString(painText, forType: .string)
                }, label: {
                    Image(systemName: "doc.on.clipboard.fill")
                })
                .foregroundColor(Color.white)
                .cornerRadius(5)
                Button {
                    speak(text: MarkdownContent(self.respText).renderPlainText())
                } label: {
                    Image(systemName: "play.circle")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }.padding(.leading, 10)
        } .frame(width: 400)
            .frame(minHeight: 400) // TODO: minHeight 可以通过翻译后的行数估计，与 400 取一个最小值。
            .frame(maxHeight: 500)
    }
}


var isPreview: Bool {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

#Preview {
    SelectedTextView(text: "单词；语言的基本单位，用来表达概念、事物或动作。语言的基本单位，用来表达概念、事物或动作。", transText: """
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

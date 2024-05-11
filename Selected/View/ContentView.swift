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
                            .markdownMargin(top: .zero, bottom: .em(0.8))
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

struct ChatTextView: View {
    var text: String
    var prompt: String
    var options: [String: String]
    @State var respText: String = "..."
    @State private var hasRep = false
    
    @Environment(\.colorScheme) private var colorScheme
    var highlighter = CustomCodeSyntaxHighlighter()
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.vertical){
                Markdown(self.respText)
                    .markdownBlockStyle(\.codeBlock, body: {label in
                        // wrap long lines
                        highlighter.setTheme(theme: codeTheme).highlightCode(label.content, language: label.language)
                                .padding()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .markdownMargin(top: .zero, bottom: .em(0.8))
                    })
                    .padding(.leading, 20.0)
                    .padding(.trailing, 20.0)
                    .padding(.top, 20)
                    .frame(width: 550, alignment: .leading)
                    .task {
                        if isPreview {
                            return
                        }
                        
                        await ChatService(prompt: prompt).chat(content: text, options: options) { content in
                            if !hasRep {
                                respText = content
                                hasRep = true
                            } else {
                                respText = respText + content
                            }
                        }
                    }
            }.frame(width: 550, height: 300)
            Divider()
            HStack{
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let painText = MarkdownContent(self.respText).renderPlainText()
                    pasteboard.setString(painText, forType: .string)
                }, label: {
                    Image(systemName: "doc.on.clipboard.fill")
                })
                .foregroundColor(Color.white)
                .cornerRadius(5)
                Button {
                    Task {
                        await speak(MarkdownContent(self.respText).renderPlainText())
                    }
                } label: {
                    Image(systemName: "play.circle")
                }.foregroundColor(Color.white)
                    .cornerRadius(5)
            }.frame(width: 550, height: 30)
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

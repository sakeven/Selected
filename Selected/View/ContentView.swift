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
                Markdown(self.transText)
                    .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: 16))))
                    .padding(.leading, 10.0)
                    .padding(.trailing, 10.0)
                    .padding(.top, 10)
                    .frame(width: 400)
                    .task {
                        if isPreview {
                            return
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
                }.frame(width: 400, height: 20)
            }
    }
}


struct ChatTextView: View {
    @State var text: String
    var prompt: String
    @State var respText: String = "请求中..."
    @State private var hasRep = false
    
    @State private var width = 100
    
   
    
    var body: some View {
        VStack(alignment: .leading) {
            Markdown(self.respText)
                .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: 16))))
                .padding(.leading, 10.0)
                .padding(.trailing, 10.0)
                .padding(.top, 10)
                .frame(width: 400)
                .task {
                    if isPreview {
                        return
                    }
                    await ChatService(prompt: prompt).chat(content: text) { content in
                        if !hasRep {
                            respText = content
                            hasRep = true
                        } else {
                            respText = respText + content
                        }
                    }
                }
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
            }.frame(width: 400, height: 20)
        }
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

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
    var highlighter = CustomCodeSyntaxHighlighter()

    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(LocalizedStringKey(message.role))
                    .foregroundStyle(.blue.gradient).font(.headline)
                Spacer()
                if message.role == "assistant" {
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
                            await speak(MarkdownContent(message.message).renderPlainText(), view: false)
                        }
                    } label: {
                        Image(systemName: "play.circle")
                    }.foregroundColor(Color.white)
                        .cornerRadius(5)
                }
            }.frame(height: 20).padding(.trailing, 30.0)

            Markdown(message.message)
                .markdownBlockStyle(\.codeBlock) {
                    codeBlock($0)
                }
//                .frame(width: 500, alignment: .leading)
                .padding(.leading, 20.0)
                .padding(.trailing, 40.0)
                .padding(.top, 5)
                .padding(.bottom, 20)
        }.frame(width: 550)
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

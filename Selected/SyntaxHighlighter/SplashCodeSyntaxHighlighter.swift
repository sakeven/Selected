//
//  SplashCodeSyntaxHighlighter.swift
//  Selected
//
//  Created by sake on 2024/3/8.
//

import SwiftUI
import Highlightr


enum CodeTheme: String {
    case dark = "monokai-sublime"
    case light = "github"
}

struct CustomCodeSyntaxHighlighter {
    private let syntaxHighlighter: Highlightr
    
    init(theme: CodeTheme) {
        let highlightr = Highlightr()!
        highlightr.setTheme(to: theme.rawValue)
        highlightr.ignoreIllegals = true
        syntaxHighlighter = highlightr
    }
    
    func highlightCode(_ content: String, language: String?) -> Text {
        guard var language = language else {
            return Text(content)
        }
        if !syntaxHighlighter.supportedLanguages().contains(language) {
            language = "plaintext"
        }
        let highlightedCode = syntaxHighlighter.highlight(content, as: language)!
        return Text(AttributedString(highlightedCode))
    }
}

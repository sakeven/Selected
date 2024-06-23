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

class CustomCodeSyntaxHighlighter {
    private let syntaxHighlighter: Highlightr
    
    // It's important to cache generated code block view
    // when we use it in a streaming Markdown content.
    // Markdown will be rendered multiple times in a very short time.
    private var cacheCode = [String: Text]()

    init() {
        let highlightr = Highlightr()!
        highlightr.ignoreIllegals = true
        syntaxHighlighter = highlightr
    }
    
    deinit {
        cacheCode = [:]
    }
    
    func setTheme(theme: CodeTheme) -> Self {
        syntaxHighlighter.setTheme(to: theme.rawValue)
        return self
    }
    
    func highlightCode(_ content: String, language: String?) -> Text {
        if let v = cacheCode[content] {
            return v
        }
        
        guard var language = language else {
            return Text(content)
        }
        
        if language == "sh" {
            language = "shell"
        }
        if !syntaxHighlighter.supportedLanguages().contains(language) {
            language = "plaintext"
        }
        let highlightedCode = syntaxHighlighter.highlight(content, as: language)!
        
        let attributedString = NSMutableAttributedString(attributedString: highlightedCode)
        let font = NSFont(name: "UbuntuMonoNFM", size: 14)!
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedString.length))

        let v = Text(AttributedString(attributedString))
        cacheCode[content] = v
        return v
    }
}

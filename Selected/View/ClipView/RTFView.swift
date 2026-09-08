//
//  RTFView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import Foundation
import SwiftUI

struct RTFView: NSViewRepresentable {
    var text: NSAttributedString

    private var displayText: NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            guard let background = attributes[.backgroundColor] as? NSColor,
                  background.alphaComponent > 0 else { return }
            // Keep a highlight's color pair intact during dark appearance mapping.
            for key in [NSAttributedString.Key.foregroundColor, .backgroundColor] {
                if let color = attributes[key] as? NSColor {
                    result.addAttribute(key, value: NSColor(name: nil) { _ in color }, range: range)
                }
            }
        }
        return result
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(displayText)
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let text = displayText
        guard let textView = nsView.documentView as? NSTextView,
              let storage = textView.textStorage,
              !storage.isEqual(to: text) else { return }
        storage.setAttributedString(text)
    }
}

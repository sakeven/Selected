//
//  TextView.swift
//  Selected
//
//  Created by sake on 2024/4/18.
//

import SwiftUI
import AppKit

struct TextView: NSViewRepresentable {
    var text: String
    var font: NSFont? = NSFont(name: "UbuntuMonoNFM", size: 14)
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // 配置滚动视图
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false // 确保不会绘制默认的背景
        
        // 配置文本视图
        textView.isEditable = false
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.string = text
        textView.font = font
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
    }
}

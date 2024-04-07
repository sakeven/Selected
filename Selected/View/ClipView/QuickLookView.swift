//
//  QuickLookView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import SwiftUI
import QuickLookUI

struct QuickLookPreview: NSViewRepresentable {
    var url: URL
    
    func makeNSView(context: Context) -> QLPreviewView {
        // 初始化并配置 QLPreviewView
        let preview = QLPreviewView()
        preview.previewItem = url as NSURL
        return preview
    }
    
    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        // 更新视图（如果需要）
        nsView.previewItem = url as NSURL
    }
}

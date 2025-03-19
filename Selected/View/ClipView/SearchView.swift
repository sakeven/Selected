//
//  SearchView.swift
//  Selected
//
//  Created by sake on 19/3/25.
//

import SwiftUI

// MARK: - 自定义搜索框（基于 NSSearchField，可以捕获方向键事件）
struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"
    var onArrowKey: (ArrowDirection) -> Void

    enum ArrowDirection {
        case up, down
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: CustomSearchField

        init(parent: CustomSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let searchField = notification.object as? NSSearchField {
                parent.text = searchField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowKey(.up)
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowKey(.down)
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }
}

// MARK: - 搜索框外层样式封装
struct SearchBarView: View {
    @Binding var searchText: String
    var onArrowKey: (CustomSearchField.ArrowDirection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            CustomSearchField(text: $searchText, placeholder: "Search", onArrowKey: onArrowKey)
                .frame(height: 28)
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

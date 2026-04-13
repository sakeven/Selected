//
//  SearchView.swift
//  Selected
//
//  Created by sake on 19/3/25.
//

import AppKit
import SwiftUI

private extension ColorScheme {
    var clipSearchFill: Color {
        self == .dark ? Color.white.opacity(0.06) : Color(red: 0.20, green: 0.34, blue: 0.46).opacity(0.08)
    }

    var clipSearchStroke: Color {
        self == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.24)
    }

    var clipSearchIcon: Color {
        self == .dark
            ? Color.white.opacity(0.9)
            : Color(red: 0.19, green: 0.29, blue: 0.4).opacity(0.92)
    }

    var clipSearchTextColor: NSColor {
        self == .dark
            ? .white.withAlphaComponent(0.95)
            : NSColor(calibratedRed: 0.16, green: 0.23, blue: 0.31, alpha: 0.96)
    }

    var clipSearchPlaceholderColor: NSColor {
        self == .dark
            ? .white.withAlphaComponent(0.4)
            : NSColor(calibratedRed: 0.32, green: 0.41, blue: 0.51, alpha: 0.82)
    }
}

// MARK: - 自定义搜索框（基于 NSTextField，可以捕获方向键事件）
struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"
    var onArrowKey: (ArrowDirection) -> Void
    var textColor: NSColor
    var placeholderColor: NSColor

    enum ArrowDirection {
        case up, down
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomSearchField

        init(parent: CustomSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
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

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.textColor = textColor
        textField.font = .systemFont(ofSize: 14)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.textColor = textColor
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
    }
}

// MARK: - 搜索框外层样式封装
struct SearchBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var searchText: String
    var onArrowKey: (CustomSearchField.ArrowDirection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(colorScheme.clipSearchIcon)
                .accessibilityHidden(true)

            CustomSearchField(
                text: $searchText,
                placeholder: "Search",
                onArrowKey: onArrowKey,
                textColor: colorScheme.clipSearchTextColor,
                placeholderColor: colorScheme.clipSearchPlaceholderColor
            )
                .frame(height: 20)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme.clipSearchFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(colorScheme.clipSearchStroke, lineWidth: 1)
        )
    }
}

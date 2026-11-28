//
//  SearchView.swift
//  Selected
//
//  Created by sake on 19/3/25.
//

import AppKit
import SwiftUI

// MARK: - 自定义搜索框（基于 NSTextField，可以捕获方向键事件）
struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
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

        func controlTextDidBeginEditing(_ notification: Notification) { updateFocus(true) }
        func controlTextDidEndEditing(_ notification: Notification) { updateFocus(false) }

        private func updateFocus(_ focused: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self, parent.isFocused != focused else { return }
                parent.isFocused = focused
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
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
        textField.font = .systemFont(ofSize: 17)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.cell?.isScrollable = true
        textField.setAccessibilityLabel(placeholder)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = textColor
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        if isFocused, nsView.currentEditor() == nil {
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView, coordinator.parent.isFocused, nsView.window?.isKeyWindow == true else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

// MARK: - 搜索框外层样式封装
struct SearchBarView: View {
    @Environment(\.locale) private var locale
    @Binding var searchText: String
    @Binding var isFocused: Bool
    var onArrowKey: (CustomSearchField.ArrowDirection) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(isFocused ? .primary : .secondary)
                .accessibilityHidden(true)

            CustomSearchField(
                text: $searchText,
                isFocused: $isFocused,
                placeholder: String(localized: "clip.search", locale: locale),
                onArrowKey: onArrowKey,
                textColor: .labelColor,
                placeholderColor: .secondaryLabelColor
            )
                .frame(maxWidth: .infinity)
                .frame(height: 24)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isFocused = true
                } label: {
                    Label("clip.search.clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(AppIconButtonStyle())
                .help(Text("clip.search.clear"))
            }
        }
    }
}

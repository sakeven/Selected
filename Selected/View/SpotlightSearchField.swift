import AppKit
import SwiftUI

struct SpotlightSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let moveSelection: (Int) -> Void
    let submit: () -> Void
    let tab: () -> Bool
    let cancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = Field()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 20)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.isScrollable = true
        field.setAccessibilityIdentifier("spotlight-input")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder
        field.setAccessibilityLabel(placeholder)
        if isFocused, field.currentEditor() == nil {
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak field] in
                guard let field, coordinator.parent.isFocused, field.window?.isKeyWindow == true else { return }
                field.window?.makeFirstResponder(field)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 400, height: 24)
    }

    private final class Field: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self, window?.isKeyWindow == true else { return }
                window?.makeFirstResponder(self)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SpotlightSearchField

        init(_ parent: SpotlightSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if parent.text != field.stringValue { parent.text = field.stringValue }
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            updateFocus(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            updateFocus(false)
        }

        private func updateFocus(_ focused: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self, parent.isFocused != focused else { return }
                parent.isFocused = focused
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                parent.moveSelection(-1)
            case #selector(NSResponder.moveDown(_:)):
                parent.moveSelection(1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.submit()
            case #selector(NSResponder.insertTab(_:)):
                return parent.tab()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.cancel()
            default:
                return false
            }
            return true
        }
    }
}

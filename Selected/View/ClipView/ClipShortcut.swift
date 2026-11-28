import AppKit

enum ClipShortcut: Equatable {
    case paste, copy, pastePlainText, focusSearch, togglePin, delete
    case quickPaste(Int)

    static let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.modifiers)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if flags == .command, let number = Int(key), (1...9).contains(number) {
            self = .quickPaste(number)
            return
        }
        switch (flags, key) {
        case ([], "\r"), ([], "\u{3}"): self = .paste
        case (.command, "\r"), (.command, "\u{3}"): self = .copy
        case ([.option, .shift], "\r"), ([.option, .shift], "\u{3}"): self = .pastePlainText
        case (.command, "f"): self = .focusSearch
        case (.command, "p"): self = .togglePin
        case ([.command, .shift], "\u{7f}"): self = .delete
        default: return nil
        }
    }
}

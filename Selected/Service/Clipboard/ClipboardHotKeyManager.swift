import Defaults
import HotKey

class ClipboardHotKeyManager {
    static let shared = ClipboardHotKeyManager()

    private var hotkey: HotKey?

    func registerHotKey() {
        guard AppRuntimeMode.current == .normal else { return }
        if hotkey != nil {
            return
        }

        hotkey = HotKey(key: .init(carbonKeyCode: Defaults[.clipboardShortcut].carbonKeyCode)!, modifiers:  Defaults[.clipboardShortcut].modifierFlags)
        hotkey?.keyDownHandler = {
            ClipWindowManager.shared.createWindow()
        }
    }

    func unregisterHotKey() {
        hotkey?.keyDownHandler = nil
        hotkey = nil
    }
}

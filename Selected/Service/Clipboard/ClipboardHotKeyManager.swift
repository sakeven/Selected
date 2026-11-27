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

        let shortcut = Defaults[.clipboardShortcut]
        hotkey = HotKey(carbonKeyCode: shortcut.carbonKeyCode, carbonModifiers: shortcut.carbonModifierFlags)
        hotkey?.keyDownHandler = {
            ClipWindowManager.shared.createWindow()
        }
    }

    func unregisterHotKey() {
        hotkey?.keyDownHandler = nil
        hotkey = nil
    }
}

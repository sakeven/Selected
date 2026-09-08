import SwiftUI

class ClipWindowController: NSWindowController, NSWindowDelegate {
    private var hotkeyMgr = EnterHotKeyManager()
    private var localKeyMonitor: Any?

    init(rootView: AnyView) {
        let window = FloatingPanel(
            contentRect: .zero,
            backing: .buffered,
            defer: false,
            key: true // 成为 key 和 main window 就可以用一些快捷键，比如方向键，以及可以文本编辑。
        )

        window.isOpaque = true
        window.backgroundColor = .clear

        super.init(window: window)

        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self // 设置代理为自己来监听窗口事件
        window.makeKeyAndOrderFront(nil)
        if clipWindowPositionManager.restorePosition(for: window) {
            return
        }

        let windowFrame = window.frame
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // 获取主屏幕的可见区域

        // 确保窗口不会超出屏幕边缘
        let x = (screenFrame.maxX - windowFrame.width) / 2
        let y = (screenFrame.maxY - windowFrame.height)*3 / 4
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            clipWindowPositionManager.storePosition(of: window)
        }
    }

    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            clipWindowPositionManager.storePosition(of: window)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowDidResignActive(_ notification: Notification) {
        self.close() // 如果需要的话
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window?.isKeyWindow == true else { return event }
            guard self.window?.attachedSheet == nil else { return event }
            if event.keyCode == Keycode.escape {
                guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return event }
                if let textView = self.window?.firstResponder as? NSTextView, textView.hasMarkedText() {
                    return event
                }
                self.close()
                return nil
            }
            guard event.keyCode == Keycode.returnKey else { return event }
            return self.hotkeyMgr.handleIfNeeded() ? nil : event
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        ClipViewModel.shared.selectedItem = nil
    }
}

private let clipWindowPositionManager = WindowPositionManager(key: "ClipboardWindowPosition")

private class EnterHotKeyManager {
    func handleIfNeeded() -> Bool {
        guard shouldHandleReturn() else {
            return false
        }

        guard let item = ClipViewModel.shared.selectedItem else {
            return false
        }

        ClipWindowManager.shared.restore(item, paste: true)
        return true
    }

    private func shouldHandleReturn() -> Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else {
            return true
        }

        if let textView = firstResponder as? NSTextView {
            return !textView.hasMarkedText()
        }

        return true
    }
}

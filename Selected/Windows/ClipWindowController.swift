import SwiftUI

class ClipWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: ClipViewModel
    private var localKeyMonitor: Any?

    init(rootView: AnyView, viewModel: ClipViewModel) {
        self.viewModel = viewModel
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
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.handleKeyEvent(event) else { return event }
            return nil
        }
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let window, window.isKeyWindow, window.attachedSheet == nil,
              event.window == nil || event.window === window else { return false }
        let flags = event.modifierFlags.intersection(ClipShortcut.modifiers)
        let isComposing = (window.firstResponder as? NSTextInputClient)?.hasMarkedText() == true
        if event.type == .flagsChanged {
            viewModel.showsQuickPasteKeys = flags == .command && !isComposing
            return false
        }
        guard event.type == .keyDown, !isComposing else { return false }
        if flags.isEmpty, event.keyCode == Keycode.escape {
            close()
            return true
        }
        guard let shortcut = ClipShortcut(event: event) else { return false }
        return event.isARepeat || viewModel.performShortcut?(shortcut) == true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        viewModel.showsQuickPasteKeys = NSEvent.modifierFlags.intersection(ClipShortcut.modifiers) == .command
    }

    func windowDidResignKey(_ notification: Notification) {
        viewModel.showsQuickPasteKeys = false
    }

    func windowWillClose(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        viewModel.selectedItem = nil
        viewModel.showsQuickPasteKeys = false
        viewModel.performShortcut = nil
    }
}

private let clipWindowPositionManager = WindowPositionManager(key: "ClipboardWindowPosition")

//
//  Spotlight.swift
//  Selected
//
//  Created by sake on 2024/8/4.
//

import Foundation
import Carbon
import ShortcutRecorder
import SwiftUI
import HotKey
import Defaults

class SpotlightHotKeyManager {
    static let shared = SpotlightHotKeyManager()

    private var hotkey: HotKey?

    init(){
        NSEvent.addGlobalMonitorForEvents(matching:
                                            [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { (event) in
            _ = SpotlightWindowManager.shared.closeWindow()
        }
    }

    func registerHotKey() {
        hotkey = HotKey(key: .init(carbonKeyCode: Defaults[.spotlightShortcut].carbonKeyCode)!, modifiers:  Defaults[.spotlightShortcut].modifierFlags)
        hotkey?.keyDownHandler = {
            SpotlightWindowManager.shared.createWindow()
        }
        NSLog("registerHotKey of spotlight")
    }

    func unregisterHotKey() {
        hotkey?.keyDownHandler = nil
        hotkey = nil
    }
}


// MARK: - window

class SpotlightWindowManager {
    static let shared =  SpotlightWindowManager()


    private var windowCtr: WindowController?

    fileprivate func createWindow() {
        windowCtr?.close()
        let view = SpotlightView()
        let window = WindowController(rootView: AnyView(view))
        windowCtr = window
        window.showWindow(nil)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window.window, queue: nil) { _ in
            self.windowCtr = nil
        }
        return
    }

    fileprivate func closeWindow() -> Bool {
        guard let windowCtr = windowCtr else {
            return true
        }
        var closed = false
        let frame =  windowCtr.window!.frame
        if !frame.contains(NSEvent.mouseLocation){
            windowCtr.close()
            closed = true
            self.windowCtr = nil
        }
        return closed
    }

    func resignKey(){
        windowCtr?.window?.resignKey()
    }

    func forceCloseWindow() {
        guard let windowCtr = windowCtr else {
            return
        }
        windowCtr.close()
        self.windowCtr = nil
    }
}


private class WindowController: NSWindowController, NSWindowDelegate {
    var hotkeyMgr = EnterHotKeyManager()

    init(rootView: AnyView) {
        let window = FloatingPanel(
            contentRect: .zero,
            backing: .buffered,
            defer: false,
            key: true // 成为 key 和 main window 就可以用一些快捷键，比如方向键，以及可以文本编辑。
        )

        super.init(window: window)

        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self // 设置代理为自己来监听窗口事件
        window.makeKeyAndOrderFront(nil)
        window.backgroundColor = .clear
        window.isOpaque = false
        if WindowPositionManager.shared.restorePosition(for: window) {
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
            WindowPositionManager.shared.storePosition(of: window)
        }
    }

    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            WindowPositionManager.shared.storePosition(of: window)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowDidResignActive(_ notification: Notification) {
        self.close() // 如果需要的话
    }

    override func showWindow(_ sender: Any?) {
        hotkeyMgr.registerHotKey()
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        hotkeyMgr.unregisterHotKey()
        ClipViewModel.shared.selectedItem = nil
    }
}


private class WindowPositionManager {
    static let shared = WindowPositionManager()
    let key = "SpotlightWindowPosition"

    func storePosition(of window: NSWindow) {
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: key)
    }

    func restorePosition(for window: NSWindow) -> Bool {
        if let frameString = UserDefaults.standard.string(forKey: key) {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
            return true
        }
        return false
    }
}

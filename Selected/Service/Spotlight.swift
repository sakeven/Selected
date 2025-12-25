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
        if hotkey != nil {
            return
        }
        hotkey = HotKey(key: .init(carbonKeyCode: Defaults[.spotlightShortcut].carbonKeyCode)!, modifiers:  Defaults[.spotlightShortcut].modifierFlags)
        hotkey?.keyDownHandler = {
            SpotlightWindowManager.shared.createWindow()
        }
    }

    func unregisterHotKey() {
        hotkey?.keyDownHandler = nil
        hotkey = nil
    }
}


// MARK: - window

class SpotlightWindowManager {
    static let shared =  SpotlightWindowManager()

    private var lock = NSLock()
    private var windowCtr: WindowController?

    fileprivate func createWindow() {
        lock.lock()
        defer {
            lock.unlock()
        }
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
        lock.lock()
        defer {
            lock.unlock()
        }

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
        lock.lock()
        defer {
            lock.unlock()
        }
        windowCtr?.window?.resignKey()
    }

    func forceCloseWindow() {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let windowCtr = windowCtr else {
            return
        }
        windowCtr.close()
        self.windowCtr = nil
    }
}


private class WindowController: NSWindowController, NSWindowDelegate {
    var showingSharingPicker = ShowingSharingPickerModel()

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
        window.contentView = NSHostingView(rootView: rootView.environmentObject(showingSharingPicker))
        window.delegate = self // 设置代理为自己来监听窗口事件
        window.makeKeyAndOrderFront(nil)
        window.backgroundColor = .clear
        window.isOpaque = false
        if windowPositionManager.restorePosition(for: window) {
            logger.debug("restorePosition")
            return
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowFrame = window.frame

        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.minY + screenFrame.height * 0.75 - windowFrame.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            logger.debug("windowDidMove")
            windowPositionManager.storePosition(of: window)
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
    }

    func windowWillClose(_ notification: Notification) {
        ClipViewModel.shared.selectedItem = nil
    }
}

private let windowPositionManager = WindowPositionManager(key: "SpotlightWindowPosition")

//
//  ChatWindow.swift
//  Selected
//
//  Created by sake on 2024/8/14.
//

import Foundation
import SwiftUI


class ChatWindowManager {
    static let shared = ChatWindowManager()

    private var lock = NSLock()
    private var windowCtrs = [ChatWindowController]()

    func closeAllWindows(_ mode: CloseWindowMode) {
        lock.lock()
        defer {lock.unlock()}

        for index in (0..<windowCtrs.count).reversed() {
            if closeWindow(mode, windowCtr: windowCtrs[index]) {
                windowCtrs.remove(at: index)
            }
        }
    }

    func createChatWindow(chatService: AIProvider, withContext ctx: ChatContext) {
        let windowController = ChatWindowController(chatService: chatService, withContext: ctx)
        closeAllWindows(.force)

        lock.lock()
        windowCtrs.append(windowController)
        lock.unlock()

        windowController.showWindow(nil)
        // 如果你需要处理窗口关闭事件，你可以添加一个通知观察者
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: windowController.window, queue: nil) { _ in
        }
    }

    private func closeWindow(_ mode: CloseWindowMode, windowCtr: ChatWindowController) -> Bool {
        if windowCtr.pinnedModel.pinned {
            return false
        }

        if case .force = mode {
            windowCtr.close()
            return true
        }
        guard let window = windowCtr.window,
              mode.shouldClose(frame: window.frame, mouseLocation: NSEvent.mouseLocation) else {
            return false
        }
        windowCtr.close()
        return true
    }

}

class ChatWindowController: NSWindowController, NSWindowDelegate {
    var resultWindow: Bool
    var onClose: (()->Void)?

    var pinnedModel: PinnedModel

    init(chatService: AIProvider, withContext ctx: ChatContext) {
        // 必须用 NSPanel 并设置 .nonactivatingPanel 以及 level 为 .screenSaver
        // 保证悬浮在全屏应用之上
        let window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 720),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false,
            key: true
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        self.resultWindow = true
        pinnedModel = PinnedModel()

        super.init(window: window)

        let view = ChatTextView(ctx: ctx, viewModel: MessageViewModel(chatService: chatService)).environmentObject(pinnedModel)
        let hostingView = NSHostingView(rootView: AnyView(view))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window.level = .screenSaver
        window.hasShadow = false
        window.contentView = hostingView
        clearBackgroundsOnAncestorChain(startingAt: window.contentView?.superview)
        window.delegate = self // 设置代理为自己来监听窗口事件

        _ = chatWindowPositionManager.restorePosition(for: window)
    }

    private func positionWindow() {
        guard let window = self.window else { return }

        if chatWindowPositionManager.restorePosition(for: window) {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
            return
        }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let x = (screenFrame.width - windowFrame.width) / 2 + screenFrame.origin.x
        let y = (screenFrame.height - windowFrame.height) * 3 / 4 + screenFrame.origin.y

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowDidResignActive(_ notification: Notification) {
        self.close() // 如果需要的话
    }

    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            chatWindowPositionManager.storePosition(of: window)
        }
    }

    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            chatWindowPositionManager.storePosition(of: window)
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        DispatchQueue.main.async{
            if let window = self.window {
                self.clearBackgroundsOnAncestorChain(startingAt: window.contentView?.superview)
            }
            self.positionWindow()
        }
    }

    private func clearBackgroundsOnAncestorChain(startingAt view: NSView?) {
        var currentView = view
        while let view = currentView {
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            if let effectView = view as? NSVisualEffectView {
                effectView.state = .inactive
            }
            currentView = view.superview
        }
    }
}

private let chatWindowPositionManager = WindowPositionManager(key: "ChatWindowPosition")

class PinnedModel: ObservableObject {
    @Published var pinned: Bool = false
}

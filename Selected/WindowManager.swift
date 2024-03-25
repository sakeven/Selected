//
//  WindowManager.swift
//  Selected
//
//  Created by sake on 2024/3/18.
//

import Foundation
import SwiftUI


enum CloseWindowMode: String {
    case expanded, original, force
}

class WindowManager {
    static let shared =  WindowManager()
    
    private var windowCtr: WindowController?
        
    func createPopBarWindow(_ ctx: SelectedTextContext) {
        let contentView = PopBarView(actions: GetActions(ctx: ctx), ctx: ctx)
        createWindow(rootView: AnyView(contentView), resultWindow: false)
    }
    
    func createTranslationWindow(withText text: String, to: String) {
        let contentView = SelectedTextView(text: text, to: to)
//        let contentView = FakeView()
        createWindow(rootView: AnyView(contentView), resultWindow: true)
    }
    
    
    func createChatWindow(withText text: String, prompt: String) {
        let contentView = ChatTextView(text: text, prompt: prompt)
        createWindow(rootView: AnyView(contentView), resultWindow: true)
    }
    
    func closeAllWindows(_ mode: CloseWindowMode) -> Bool {
        guard let windowCtr = windowCtr else {
            return false
        }
        return closeWindow(mode, windowCtr: windowCtr)
    }
    
    private func createWindow(rootView: AnyView, resultWindow: Bool) {
        // 使用任意视图创建 WindowController
        let windowController = WindowController(rootView: rootView, resultWindow: resultWindow)
        windowCtr?.close()
        windowController.showWindow(nil)
        windowCtr = windowController
        
        // 如果你需要处理窗口关闭事件，你可以添加一个通知观察者
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: windowController.window, queue: nil) { _ in
            self.windowCtr = nil
        }
    }
    
    private func closeWindow(_ mode: CloseWindowMode, windowCtr: WindowController) -> Bool {
        var closed = false
        switch mode {
            case .expanded:
                let frame =  windowCtr.window!.frame
                let expandedFrame = NSRect(x: frame.origin.x - kExpandedLength,
                                           y: frame.origin.y - kExpandedLength,
                                           width: frame.size.width + kExpandedLength * 2,
                                           height: frame.size.height + kExpandedLength * 2)
                if !expandedFrame.contains(NSEvent.mouseLocation){
                    windowCtr.close()
                    closed = true
                }
                
            case .original:
                let frame =  windowCtr.window!.frame
                if !frame.contains(NSEvent.mouseLocation){
                    windowCtr.close()
                    closed = true
                }
                
            case .force:
                windowCtr.close()
                closed = true
        }
        return closed
    }
    
}


private class WindowController: NSWindowController, NSWindowDelegate {
    init(rootView: AnyView, resultWindow: Bool) {
        var window: NSWindow
        // 必须用 NSPanel 并设置 .nonactivatingPanel 以及 level 为 .screenSaver
        // 保证悬浮在全屏应用之上
        window = FloatingPanel(
                contentRect: .zero,
                backing: .buffered,
                defer: false
        )
        
        if !resultWindow{
            window.isOpaque = true
            window.backgroundColor = .clear
        }
        
        super.init(window: window)
        
        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self // 设置代理为自己来监听窗口事件
        
        let windowFrame = window.frame
        NSLog("windowFrame \(windowFrame.height), \(windowFrame.width)")
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // 获取主屏幕的可见区域
        
        let loc = NSEvent.mouseLocation
        if resultWindow {
            let windowWidth: CGFloat = 200
            let windowHeight: CGFloat = 200
            var mouseLocation = loc // 获取鼠标当前位置

            // 确保窗口不会超出屏幕右边缘或底部
            mouseLocation.x = min(abs(mouseLocation.x-20), screenFrame.maxX - windowWidth)
            mouseLocation.y = max(abs(mouseLocation.y-20), screenFrame.minY + windowHeight)
            window.setFrameOrigin(NSPoint(x: mouseLocation.x, y: mouseLocation.y))
        } else {
            // 确保窗口不会超出屏幕边缘
            let x = min(screenFrame.maxX - windowFrame.width,
                        max(loc.x - windowFrame.width/2, screenFrame.minX))
            window.setFrameOrigin(NSPoint(x: x, y: loc.y + 18))
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
}

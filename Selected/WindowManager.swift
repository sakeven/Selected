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

func createTemporaryURLForData(_ data: Data, fileName: String) -> URL? {
    // 获取临时目录 URL
    let tempDirectoryURL = FileManager.default.temporaryDirectory

    // 创建新临时文件 URL
    let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)
    
    do {
        // 将数据写入临时文件
        try data.write(to: tempFileURL)
        return tempFileURL
    } catch {
        print("Error writing data to temporary file: \(error)")
        return nil
    }
}


class WindowManager {
    static let shared =  WindowManager()
    
    // TODO: lock
    private var windowCtr: WindowController?
    
    func createPopBarWindow(_ ctx: SelectedTextContext) {
        let contentView = PopBarView(actions: GetActions(ctx: ctx), ctx: ctx)
        createWindow(rootView: AnyView(contentView), windType: .Transparent)
    }
    
    func createTranslationWindow(withText text: String, to: String) {
        let contentView = TranslationView(text: text, to: to)
        createWindow(rootView: AnyView(contentView), windType: .Alpha)
    }
    
    func createAudioPlayerWindow(_ audio: Data) {
        guard let url = createTemporaryURLForData(audio, fileName: "selected-tmptts.mp3") else{
            return
        }
        let contentView = AudioPlayerView(audioURL: url)
        createWindow(rootView: AnyView(contentView), windType: .Opaque) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error remove temporary file: \(error)")
                return
            }
        }
    }
    
    
    func createChatWindow(chatService: AIChatService, withText text: String) {
        let contentView = ChatTextView(text: text, viewModel: MessageViewModel(chatService: chatService))
        createWindow(rootView: AnyView(contentView), windType: .Alpha)
    }
    
    func closeOnlyPopbarWindows(_ mode: CloseWindowMode) -> Bool {
        guard let windowCtr = windowCtr else {
            return false
        }
        if showingSharingPicker {
            return false
        }
        if !windowCtr.resultWindow {
            return closeWindow(mode, windowCtr: windowCtr)
        }
        return false
    }
    
    func closeAllWindows(_ mode: CloseWindowMode) -> Bool {
        guard let windowCtr = windowCtr else {
            return false
        }
        if showingSharingPicker {
            return false
        }
        return closeWindow(mode, windowCtr: windowCtr)
    }
    
    private func createWindow(rootView: AnyView, windType: WindowType) {
        // 使用任意视图创建 WindowController
        let windowController = WindowController(rootView: rootView, windType: windType)
        windowCtr?.close()
        windowController.showWindow(nil)
        windowCtr = windowController
        
        // 如果你需要处理窗口关闭事件，你可以添加一个通知观察者
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: windowController.window, queue: nil) { _ in
            self.windowCtr = nil
        }
    }
    
    private func createWindow(rootView: AnyView, windType: WindowType, onClose: @escaping ()->Void) {
        // 使用任意视图创建 WindowController
        let windowController = WindowController(rootView: rootView, windType: windType)
        windowController.onClose = onClose
        windowCtr?.close()
        windowController.showWindow(nil)
        windowCtr = windowController
        
        // 如果你需要处理窗口关闭事件，你可以添加一个通知观察者
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: windowController.window, queue: nil) { _ in
            self.windowCtr = nil
        }
    }
    
    func createTextWindow(_ text: String) {
        // 使用任意视图创建 WindowController
        let windowController = WindowController(text: text)
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
                    self.windowCtr = nil
                    closed = true
                }
                
            case .original:
                let frame =  windowCtr.window!.frame
                if !frame.contains(NSEvent.mouseLocation){
                    windowCtr.close()
                    self.windowCtr = nil
                    closed = true
                }
                
            case .force:
                windowCtr.close()
                self.windowCtr = nil
                closed = true
        }
        return closed
    }
    
}

enum WindowType {
case Transparent, Alpha, Opaque
}

private class WindowController: NSWindowController, NSWindowDelegate {
    var resultWindow: Bool
    var onClose: (()->Void)?
    
    init(text: String) {
        let window = TextResultWindow(text)
        window.alphaValue = 0.9
        window.isOpaque = true
        window.backgroundColor = .clear
        self.resultWindow = true
        
        super.init(window: window)
        
        window.center()
        window.level = .screenSaver
        window.delegate = self // 设置代理为自己来监听窗口事件
        
        let windowFrame = window.frame
        NSLog("windowFrame \(windowFrame.height), \(windowFrame.width)")
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // 获取主屏幕的可见区域
        
        let mouseLocation = NSEvent.mouseLocation  // 获取鼠标当前位置
        
        
        // 确保窗口不会超出屏幕边缘
        let x = min(screenFrame.maxX - windowFrame.width,
                    max(mouseLocation.x - windowFrame.width/2, screenFrame.minX))
        
        var y =  mouseLocation.y + 18
        if y > screenFrame.maxY {
            y =  mouseLocation.y - 30 - 18
        }
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    init(rootView: AnyView, windType: WindowType) {
        var window: NSWindow
        // 必须用 NSPanel 并设置 .nonactivatingPanel 以及 level 为 .screenSaver
        // 保证悬浮在全屏应用之上
        let key = windType == .Alpha
        window = FloatingPanel(
            contentRect: .zero,
            backing: .buffered,
            defer: false,
            key: key
        )
        
        switch windType {
        case .Transparent:
            window.isOpaque = true
            window.backgroundColor = .clear
            self.resultWindow = false
        case .Alpha:
            window.alphaValue = 0.9
            self.resultWindow = true
        case .Opaque:
            window.isOpaque = true
            window.backgroundColor = .clear
            self.resultWindow = true
        }

        
        super.init(window: window)
        
        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self // 设置代理为自己来监听窗口事件
        
        let windowFrame = window.frame
        NSLog("windowFrame \(windowFrame.height), \(windowFrame.width)")
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero // 获取主屏幕的可见区域
        
        let mouseLocation = NSEvent.mouseLocation  // 获取鼠标当前位置
        
        if windType  == .Alpha {
            // 确保窗口不会超出屏幕边缘
            let x = (screenFrame.maxX - windowFrame.width) / 2
            let y = (screenFrame.maxY - windowFrame.height)*3 / 4
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else{
            // 确保窗口不会超出屏幕边缘
            let x = min(screenFrame.maxX - windowFrame.width,
                        max(mouseLocation.x - windowFrame.width/2, screenFrame.minX))
            
            var y =  mouseLocation.y + 18
            if y > screenFrame.maxY {
                y =  mouseLocation.y - 30 - 18
            }
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    deinit{
        stopSpeak()
        if let onClose = onClose {
            onClose()
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


func TextResultWindow(_ text: String) -> NSWindow{
    let window = FloatingPanel(
        contentRect: .zero,
        backing: .buffered,
        defer: false
    )
    
    let view = PopResultView(text: text)
    window.contentView = NSHostingView(rootView: view)
    return window
}

//
//  Clipboard.swift
//  Selected
//
//  Created by sake on 2024/3/31.
//

import Foundation
import Cocoa
import SwiftUI
import Carbon
import Defaults

class ClipService {
    static let shared = ClipService()
    
    private var eventMonitor: Any?
    private var pasteboard: NSPasteboard = .general
    
    //
    private var lock = NSLock()
    private var changeCount: Int = 0
    private var skip = false
    
    init() {
        changeCount = pasteboard.changeCount
        NSEvent.addGlobalMonitorForEvents(matching:
                                            [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { (event) in
            _ = ClipWindowManager.shared.closeWindow()
        }
    }
    
    func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            guard Defaults[.enableClipboard] else { return }
            
            NSLog("clip event \(eventTypeMap[event.type]!)")
            
            var shouldSkip = false
            lock.lock()
            shouldSkip = skip
            lock.unlock()
            
            if shouldSkip {
                return
            }
            checkPasteboard()
        }
    }
    
    func pauseMonitor(_ id: String) {
        lock.lock()
        NSLog("pasteboard \(id) pauseMonitor changeCount \(changeCount)")
        skip = true
        lock.unlock()
    }
    
    func resumeMonitor(_ id: String) {
        lock.lock()
        skip = false
        changeCount = pasteboard.changeCount
        NSLog("pasteboard \(id) resumeMonitor changeCount \(changeCount)")
        lock.unlock()
    }
    
    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        if changeCount != currentChangeCount {
            lock.lock()
            changeCount = currentChangeCount
            lock.unlock()
            
            NSLog("pasteboard changeCount \(changeCount)")
            
            guard pasteboard.types != nil else {
                return
            }
            
            // 剪贴板内容发生变化，处理变化
            NSLog("pasteboard \(String(describing: pasteboard.types))")
            guard let clipData = ClipData(pasteboard: pasteboard) else {
                return
            }
            
            if skip {
                return
            }
            if clipData.types.isEmpty {
                return
            }
            PersistenceController.shared.store(clipData)
        }
    }
}

private let SupportedPasteboardTypes: Set<NSPasteboard.PasteboardType> = [
    .URL,
    .color,
    .html,
    .pdf,
    .png,
    .rtf,
    .string,
    .fileURL,
    NSPasteboard.PasteboardType("org.chromium.source-url"),
]

struct ClipItem {
    var type: NSPasteboard.PasteboardType
    var data: Data
}

struct ClipData: Identifiable {
    var id: String
    var timeStamp: Int64
    var types: [NSPasteboard.PasteboardType]
    var appBundleID: String
    var items: [ClipItem]
    
    var plainText: String?
    var url: String?
    
    static private func filterPasteboardTypes(_ types: [NSPasteboard.PasteboardType]?) -> [NSPasteboard.PasteboardType] {
        guard let types = types else {
            return []
        }
        
        var support = [NSPasteboard.PasteboardType]()
        for t in types {
            if SupportedPasteboardTypes.contains(t) {
                support.append(t)
            }
        }
        return support
    }
    
    init?(pasteboard: NSPasteboard) {
        self.id = UUID().uuidString
        self.timeStamp = Int64(Date().timeIntervalSince1970*1000)
        self.appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        self.types = ClipData.filterPasteboardTypes(pasteboard.types)
        
        var items = [ClipItem]()
        for type in types {
            let item = ClipItem(type: type, data: pasteboard.data(forType: type)!)
            items.append(item)
            
            if type == .string {
                if let content = pasteboard.string(forType: type) {
                    plainText = content
                }
            } else if type.rawValue == "org.chromium.source-url" {
                if let content = pasteboard.string(forType: type) {
                    url = content
                }
            } else if type == .fileURL {
                if let content = pasteboard.string(forType: type) {
                    url = content
                }
            } else if type == .URL {
                if let content = pasteboard.string(forType: type) {
                    url = content
                }
            } else if type == .png {
                //                TODO: OCR
                //                let image = NSImage(data: item.data)!
                //                recognizeTextInImage(image)
            }
        }
        if (types.first == .html || types.first == .rtf ) && self.plainText == nil {
            return nil
        }
        self.items = items
    }
}

extension ClipData: Hashable {
    static func == (lhs: ClipData, rhs: ClipData) -> Bool {
        return lhs.timeStamp == rhs.timeStamp
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(timeStamp)
    }
}

extension String {
    func tokenize() -> [String] {
        let word = self
        let tokenize = CFStringTokenizerCreate(kCFAllocatorDefault, word as CFString?, CFRangeMake(0, word.count), kCFStringTokenizerUnitWord, CFLocaleCopyCurrent())
        CFStringTokenizerAdvanceToNextToken(tokenize)
        var range = CFStringTokenizerGetCurrentTokenRange(tokenize)
        var keyWords : [String] = []
        while range.length > 0 {
            let wRange = word.index(word.startIndex, offsetBy: range.location)..<word.index(word.startIndex, offsetBy: range.location + range.length)
            let keyWord = String(word[wRange])
            keyWords.append(keyWord)
            CFStringTokenizerAdvanceToNextToken(tokenize)
            range = CFStringTokenizerGetCurrentTokenRange(tokenize)
        }
        return keyWords
        
    }
}

private var globalHotKeyHandler: EventHandlerRef?

// 热键激活时调用的全局函数
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    
    var receivedHotKeyID = EventHotKeyID()
    
    // 获取热键ID
    let err = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &receivedHotKeyID)
    if err == noErr {
        // 确认是哪个热键被按下
        if receivedHotKeyID.signature == EnterHotKeyManager.hotKeyId.signature && receivedHotKeyID.id == EnterHotKeyManager.hotKeyId.id {
            guard let item = ClipViewModel.shared.selectedItem else {
                return noErr
            }
            let id = UUID().uuidString
            ClipService.shared.pauseMonitor(id)
            let pboard = NSPasteboard.general
            pboard.clearContents()
            for t in item.getItems() {
                pboard.setData(t.data, forType: NSPasteboard.PasteboardType(rawValue: t.type!))
            }
            PersistenceController.shared.updateClipHistoryData(item)
            // 粘贴时需要取消 key window，才能复制到当前的应用上。
            ClipWindowManager.shared.resignKey()
            PressPasteKey()
            ClipWindowManager.shared.forceCloseWindow()
            ClipService.shared.resumeMonitor(id)
        } else {
            ClipWindowManager.shared.createWindow()
        }
    }
    
    return noErr
}

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyId: EventHotKeyID
    private var hotKeyRef: EventHotKeyRef?
    
    init() {
        hotKeyId = EventHotKeyID(signature: OSType("opts".fourCharCodeValue), id: 1)
    }
    
    func registerHotKey() {
        if hotKeyRef != nil {
            return
        }
        
        RegisterEventHotKey(Defaults[.clipboardShortcut].carbonKeyCode,  Defaults[.clipboardShortcut].carbonModifierFlags, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // 安装事件处理器
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &globalHotKeyHandler)
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef = globalHotKeyHandler {
            RemoveEventHandler(handlerRef)
        }
    }
}


class EnterHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    
    static let hotKeyId = EventHotKeyID(signature: OSType("entr".fourCharCodeValue), id: 2)
    
    func registerHotKey() {
        let spaceKey = UInt32(kVK_Return)
        NSLog("RegisterEventHotKey")
        RegisterEventHotKey(spaceKey, 0, EnterHotKeyManager.hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            NSLog("UnregisterEventHotKey")
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: NSPasteboard.PasteboardType) {
        if let desc = descriptionOfPasteboardType[value] {
            appendInterpolation(desc)
        } else {
            appendInterpolation("unknown")
        }
    }
}

let descriptionOfPasteboardType: [NSPasteboard.PasteboardType: String]  = [
    .URL: "URL",
    .png: "PNG image",
    .html: "HTML",
    .pdf: "PDF",
    .rtf: "rich text format",
    .string: "plain text",
    .fileURL: "file"
]

// MARK: - window

class ClipWindowManager {
    static let shared =  ClipWindowManager()
    
    
    private var windowCtr: ClipWindowController?
    
    fileprivate func createWindow() {
        windowCtr?.close()
        let view = ClipView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        let window = ClipWindowController(rootView: AnyView(view))
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


private class ClipWindowController: NSWindowController, NSWindowDelegate {
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
    
    func storePosition(of window: NSWindow) {
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: "windowPosition")
    }
    
    func restorePosition(for window: NSWindow) -> Bool {
        if let frameString = UserDefaults.standard.string(forKey: "windowPosition") {
            let frame = NSRectFromString(frameString)
            window.setFrame(frame, display: true)
            return true
        }
        return false
    }
}

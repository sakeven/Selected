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


class ClipService {
    static let shared = ClipService()
    
    private var eventMonitor: Any?
    private var pasteboard: NSPasteboard = .general
    private var cache = [ClipData]()
    
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
    
    func getHistory() -> [ClipData] {
        return cache
    }
    
    private func checkPasteboard() {
       
//        defer {}

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
            let clipData = ClipData(pasteboard: pasteboard)
            if skip {
                return
            }
            cache.insert(clipData, at: 0)
            if cache.count > 10 {
                cache.remove(at: 10)
            }
        }
    }
}

struct ClipData: Identifiable {
    var id: String
    var timeStamp: Int64
    var types: [NSPasteboard.PasteboardType]
    var appBundleID: String
    
    var plainText: String?
    var rtf: String?
    var html: String?
    var png: Data?
    var url: String?
    
    init(pasteboard: NSPasteboard) {
        self.id = UUID().uuidString
        self.timeStamp = Int64(Date().timeIntervalSince1970*1000)
        self.types = pasteboard.types!
        self.appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"

        
        for type in types {
            if type == .rtf {
                if let content = pasteboard.string(forType: type) {
                    rtf = content
                }
            } else if type.rawValue == "public.utf8-plain-text" {
                if let content = pasteboard.string(forType: type) {
                    plainText = content
                }
            } else if type == .html {
                if let content = pasteboard.string(forType: type) {
                    html = content
                }
            } else if type == .png {
                if let content = pasteboard.data(forType: type) {
                    png = content
                }
            } else if type.rawValue == "org.chromium.source-url" {
                if let content = pasteboard.string(forType: type) {
                    url = content
                }
            }
        }
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
    print("全局热键 Option+Space 被触发")
    
    ClipWindowManager.shared.createWindow()
    return noErr
}

class HotKeyManager {
    private var hotKeyId: EventHotKeyID
    private var hotKeyRef: EventHotKeyRef?
        
    init() {
        hotKeyId = EventHotKeyID(signature: OSType("opts".fourCharCodeValue), id: 1)
    }
    
    func registerHotKey() {
        let optionKey = UInt32(optionKey) // optionKey是一个来自于Carbon框架中kEventHotKey...系列常量的标识符
        let spaceKey = UInt32(kVK_Space)
        
        RegisterEventHotKey(spaceKey, optionKey, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
        
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

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}

// MARK: - test
private var testWindow: ClipWindowController?

struct ClipDataView: View {
    var data: ClipData
    var body: some View {
            VStack(alignment: .leading){
                if data.png != nil {
                    Image(nsImage: NSImage(data: data.png!)!).resizable().aspectRatio(contentMode: .fit)
                } else if data.rtf != nil {
                    RTFView(rtfData: data.rtf!)
                } else if data.plainText != nil {
                    ScrollView{
                        HStack{
                            Text(data.plainText!)
                            Spacer()
                        }
                    }
                }
                Divider()
                
                HStack {
                    Text("Application:")
                    Spacer()
                    getIcon(data.appBundleID)
                    Text(getAppName(data.appBundleID))
                }
                
                HStack {
                    Text("Date:")
                    Spacer()
                    Text("\(getDate(ts:data.timeStamp))")
                }
                
                if let url = data.url {
                    HStack {
                        Text("URL:")
                        Spacer()
                        Link(destination: URL(string: url)!, label: {
                            Text(url).lineLimit(1)
                        })
                    }
                }
            }.padding().frame(width: 550)
    }
    
    
    private func getAppName(_ bundleID: String) -> String {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }
    
    private func getIcon(_ bundleID: String) -> some View {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return AnyView(Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path)))
    }
}

func getDate(ts: Int64) -> Date {
    return Date(timeIntervalSince1970: TimeInterval(ts/1000))
}

struct RTFView: NSViewRepresentable {
    var rtfData: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false // 设为false禁止编辑
        textView.autoresizingMask = [.width]
        textView.translatesAutoresizingMaskIntoConstraints = true
        if let attributedString =
            try? NSMutableAttributedString(data: rtfData.data(using: .utf8)!,
                                    options: [
                                        .documentType: NSAttributedString.DocumentType.rtf],
                                    documentAttributes: nil) {
            let originalRange = NSMakeRange(0, attributedString.length);
            attributedString.addAttribute(NSAttributedString.Key.backgroundColor,  value: NSColor.clear, range: originalRange)

            textView.textStorage?.setAttributedString(attributedString)
        }
        textView.drawsBackground = false // 确保不会绘制默认的背景
        textView.backgroundColor = .clear

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false // 确保不会绘制默认的背景
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 用于更新视图
    }
}

struct ClipView: View {
    var datas: [ClipData]
    @State var eventMonitor: Any?
    
    // 默认选择第一条，必须同时设置 List 和 NavigationLink 的 selection
    @State var selected : Int64?
 
    var body: some View {
        NavigationView{
            List(datas, id: \.self.timeStamp, selection: $selected){
                    clipData in
                NavigationLink(destination: ClipDataView(data: clipData), tag: clipData.timeStamp, selection: $selected){
                    if clipData.types.first == .png {
                        Label(
                            title: { Text("Image").padding(.leading, 10)},
                            icon: {
                                Image(nsImage: NSImage(data: clipData.png!)!).resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                            }
                        )
                    } else if clipData.types.first == .rtf ||
                                clipData.types.first == .string ||
                                clipData.types.first == .html
                    {
                        Label(
                            title: { Text(clipData.plainText!.trimmingCharacters(in: .whitespacesAndNewlines)).lineLimit(1).frame(alignment: .leading).padding(.leading, 10) },
                            icon: { Image(systemName: "text.quote").resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                        )
                    }
                }.frame(height: 30)
            }.frame(width: 250).frame(minWidth: 250, maxWidth: 250) .onAppear(){
                selected = datas.first?.timeStamp
            }
             
            if datas.isEmpty {
                Text("Clipboard History")
            }
        }.frame(width: 800, height: 400)
    }
}

#Preview {
    ClipView(datas: ClipService.shared.getHistory())
}


class ClipWindowManager {
    static let shared =  ClipWindowManager()
            
    private var windowCtr: ClipWindowController?
    
    fileprivate func createWindow() {
        windowCtr?.close()
        let window = ClipWindowController(rootView: AnyView(ClipView(datas: ClipService.shared.getHistory())))
        windowCtr = window
        window.showWindow(nil)
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
                }
        return closed
    }
    
}


private class ClipWindowController: NSWindowController, NSWindowDelegate {
    init(rootView: AnyView) {
        let window = FloatingPanel(
            contentRect: .zero,
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self // 设置代理为自己来监听窗口事件
        
        if WindowPositionManager.shared.restorePosition(for: window) {
           return
        }
        
        let windowFrame = window.frame
        NSLog("windowFrame \(windowFrame.height), \(windowFrame.width)")
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
        super.showWindow(sender)
    }
}


class WindowPositionManager {
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

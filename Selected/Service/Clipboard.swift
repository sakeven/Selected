//
//  Clipboard.swift
//  Selected
//
//  Created by sake on 2024/3/31.
//

import Foundation
import Cocoa
import SwiftUI

class ClipService {
    static let shared = ClipService()
    
    private var eventMonitor: Any?
    private var pasteboard: NSPasteboard = .general
    private var cache = [ClipData]()
    
    //
    private var lock = NSLock()
    private var changeCount: Int = 0
    private var skip = false
    
    
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
            
            if event.type == .leftMouseUp {
                usleep(500000)
            }
            checkPasteboard()
        }
    }
    
    func pauseMonitor() {
        lock.lock()
        skip = true
        lock.unlock()
    }
    
    func resumeMonitor() {
        lock.lock()
        skip = false
        changeCount = pasteboard.changeCount
        lock.unlock()
    }
    
    func getHistory() -> [ClipData] {
        return cache
    }
    
    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        if changeCount != currentChangeCount {
            lock.lock()
            changeCount = currentChangeCount
            lock.unlock()

            guard let types = pasteboard.types else {
                return
            }
            
            // 剪贴板内容发生变化，处理变化
            NSLog("pasteboard \(String(describing: pasteboard.types))")
            let clipData = ClipData(pasteboard: pasteboard)
            cache.insert(clipData, at: 0)
            if cache.count > 10 {
                cache.remove(at: 10)
            }
        }
    }
}

struct ClipData {
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
        self.timeStamp = Int64(Date().timeIntervalSince1970)
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
//                        NSLog("read png")
//                        testWindow?.close()
//                        let window = ImageWindowController(rootView: AnyView(ImageView(content: content)))
//                        testWindow = window
//                        window.showWindow(nil)
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

// MARK: - test
private var testWindow: ImageWindowController?


struct ImageView: View {
    var content: Data
    
    var body: some View {
        Image(nsImage: NSImage(data: content)!).resizable().aspectRatio(contentMode: .fit).frame(minWidth: 200, minHeight: 200)
    }
}


private class ImageWindowController: NSWindowController, NSWindowDelegate {
    init(rootView: AnyView) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable,.resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.center()
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: rootView)
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

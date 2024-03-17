//
//  App.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import SwiftUI
import Accessibility
import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 不需要主窗口，不需要显示在 dock 上
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
        requestAccessibilityPermissions()
        PluginManager.shared.loadPlugins()
        ConfigurationManager.shared.loadConfiguration()
        DispatchQueue.main.async {
            monitorMouseMove()
        }
    }
}


@main
struct SelectedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra() {
            MenuItemView()
        } label: {
            Label {
                Text("Selected")
            } icon: {
                Image(systemName: "pencil.and.scribble")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
            .help("Selected")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            SelectedMainMenu()
        }
        Settings {
            SettingsView()
        }
    }
}


func requestAccessibilityPermissions() {
    // 判断权限
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options)
    
    NSLog("accessEnabled: \(accessEnabled)")
    
    if !accessEnabled {
        // 请求权限
        // 注意不能是 sandbox，否则辅助功能里无法看到这个 app
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let kExpandedLength: CGFloat = 100

// 监听鼠标移动
func monitorMouseMove() {
    var eventState = EventState()
    var hoverWorkItem: DispatchWorkItem?
    var lastSelectedText = ""
    
    NSEvent.addGlobalMonitorForEvents(matching:
                                        [.mouseMoved, .leftMouseUp, .leftMouseDragged, .keyDown]
    ) { (event) in
        if event.type == .mouseMoved {
            windowControllers.forEach { WindowController in
                let frame =  WindowController.window!.frame
                let expandedFrame = NSRect(x: frame.origin.x - kExpandedLength,
                                           y: frame.origin.y - kExpandedLength,
                                           width: frame.size.width + kExpandedLength * 2,
                                           height: frame.size.height + kExpandedLength * 2)
                
                if !expandedFrame.contains(NSEvent.mouseLocation){
                    WindowController.close()
                    lastSelectedText = ""
                }
            }
            eventState.lastMouseEventType = .mouseMoved
        } else {
            NSLog("event \(eventTypeMap[event.type]!)  \(eventTypeMap[eventState.lastMouseEventType]!)")
            var updatedSelectedText = false
            if eventState.isSelected(event: event) {
                if let ctx = getSelectedText() {
                    NSLog("SelectedText \(ctx.Text)")
                    if !ctx.Text.isEmpty {
                        updatedSelectedText = true
                        if lastSelectedText != ctx.Text {
                            lastSelectedText = ctx.Text
                            hoverWorkItem?.cancel()
                            
                            let workItem = DispatchWorkItem {
                                createSwiftUIWindow(ctx: ctx)
                            }
                            hoverWorkItem = workItem
                            // 在 0.2 秒后执行
                            // 解决，3 连击选定整行是从 2 连击加一次连击产生的。所以会在短时间内出现2个2次连续鼠标左键释放。
                            // 导致获取选定文本两次，绘制、关闭、再绘制窗口，造成窗口闪烁。
                            // 如果 0.2 秒内再次有点击的话，就取消之前的绘制窗口，这样能避免窗口闪烁。
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
                        }
                    }
                }
            }
            if !updatedSelectedText &&
                getBundleID() !=  SelfBundleID {
                lastSelectedText = ""
                closeAllWindow()
            }
        }
    }
    NSLog("monitorMouseMove")
}

struct EventState {
    // 在 vscode、zed 里，使用在没有任何选择的文本时，cmd+c 可以复制整行。
    // 而这两个 app 只能通过 cmd+c 获取选中的文本。
    // 导致如果我们只监听 leftMouseUp 的话，会导致无论点击在哪里，都会形式悬浮栏。
    // 所以这里，我们改成，如果当前是 leftMouseUp：
    // 1. 判断上次 leftMouseUp 的时间是否小于 0.5s，这个是鼠标左键连击的判断方法
    //    双击选词，三击选行。
    // 2. 判断上次是否是 leftMouseDragged。这表示左键单击+拖拽选择文本。
    // 另外我们还监听了：cmd+A（全选），以及 cmd+shift+arrow(部分选择)。
    var lastLeftMouseUPTime = 0.0
    var lastMouseEventType: NSEvent.EventType = .leftMouseUp
    
    let keyCodeArrows: [UInt16] = [Keycode.leftArrow, Keycode.rightArrow, Keycode.downArrow, Keycode.upArrow]
    
    mutating func isSelected(event: NSEvent ) -> Bool {
        defer {
            if event.type != .keyDown {
                lastMouseEventType = event.type
            }
        }
        if event.type == .leftMouseUp {
            let selected =  lastMouseEventType == .leftMouseDragged ||
            ((lastMouseEventType == .leftMouseUp) && (event.timestamp - lastLeftMouseUPTime < 0.5))
            lastLeftMouseUPTime = event.timestamp
            return selected
        } else if event.type == .keyDown {
            if event.keyCode == Keycode.a {
                return event.modifierFlags.contains(.command) &&
                !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.control)
            } else if keyCodeArrows.contains( event.keyCode) {
                let keyMask: NSEvent.ModifierFlags =  [.command, .shift]
                return event.modifierFlags.intersection(keyMask) == keyMask
            }
        }
        return false
    }
}

let eventTypeMap: [ NSEvent.EventType: String] = [
    .mouseMoved: "mouseMoved",
    .keyDown: "keydonw",
    .leftMouseUp: "leftMouseUp",
    .leftMouseDragged: "leftMouseDragged"
]


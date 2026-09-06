//
//  App.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import SwiftUI
import Accessibility
import AppKit
import Foundation
import Defaults
import os


let SelfBundleID = Bundle.main.bundleIdentifier ?? "io.kitool.Selected"

let logger = Logger(subsystem: SelfBundleID, category: "")

var isPreview: Bool {
    let environment = ProcessInfo.processInfo.environment
    return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
}


class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isPreview {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreviewHostView())
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = window
            return
        }

        let removedOpenAIModels = [
            "gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5-mini", "gpt-5", "gpt-5-pro",
            "gpt-4.1", "gpt-4.1-mini", "o4-mini", "o3", "gpt-4o", "gpt-4o-mini", "o3-mini"
        ]
        if removedOpenAIModels.contains(Defaults[.openAIModel]) {
            let smallerModels = ["gpt-5-mini", "gpt-4.1-mini", "o4-mini", "gpt-4o-mini", "o3-mini"]
            Defaults[.openAIModel] = smallerModels.contains(Defaults[.openAIModel]) ? .gpt5_6_terra : .gpt5_6_sol
        }
        if removedOpenAIModels.contains(Defaults[.openAITranslationModel]) {
            Defaults[.openAITranslationModel] = .gpt5_6_luna
        }

        setDefaultAppForCustomFileType()
        // 不需要主窗口，不需要显示在 dock 上
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
        requestAccessibilityPermissions()

        DispatchQueue.main.async {
            PersistenceController.shared.startDailyTimer()
        }

        PluginManager.shared.loadPlugins()
        ConfigurationManager.shared.loadConfiguration()
        DispatchQueue.main.async {
            monitorMouseMove()
        }
        DispatchQueue.main.async {
            ClipService.shared.startMonitoring()
        }

        DispatchQueue.main.async {
            ClipboardHotKeyManager.shared.registerHotKey()
            SpotlightHotKeyManager.shared.registerHotKey()
        }

        // 注册空间改变通知
        // 这里不能使用 NotificationCenter.default.
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(spaceDidChange),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil)
    }

    @objc func spaceDidChange() {
        // 当空间改变时触发
        ClipWindowManager.shared.forceCloseWindow()
        ChatWindowManager.shared.closeAllWindows(.force)
        SpotlightWindowManager.shared.forceCloseWindow()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // 处理打开的文件
            logger.debug("\(url.path)")
            do {
                try PluginManager.shared.install(url: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "插件安装失败"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        // 当 app 变为活跃时关闭全局热键
        ClipboardHotKeyManager.shared.unregisterHotKey()
        SpotlightHotKeyManager.shared.unregisterHotKey()
    }

    func applicationDidResignActive(_ notification: Notification) {
        if Defaults[.enableClipboard] {
            // 当 app 退到后台时开启全局热键
            ClipboardHotKeyManager.shared.registerHotKey()
        }
        SpotlightHotKeyManager.shared.registerHotKey()
    }
}


func setDefaultAppForCustomFileType() {
    let customUTI = "io.kitool.selected.ext"
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.kitool.Selected"
    logger.info("bundleIdentifier \(bundleIdentifier)")

    LSSetDefaultRoleHandlerForContentType(customUTI as CFString, .editor, bundleIdentifier as CFString)
}


@main
struct SelectedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!isPreview)) {
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
        }.handlesExternalEvents(matching: [])
        Settings {
            if isPreview {
                PreviewHostView()
            } else {
                SettingsView()
            }
        }
    }
}

private struct PreviewHostView: View {
    var body: some View {
        Color.white
            .opacity(0.001)
            .frame(width: 16, height: 16)
            .allowsHitTesting(false)
    }
}


func requestAccessibilityPermissions() {
    // 判断权限
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options)

    logger.info("accessEnabled: \(accessEnabled)")

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
                                        [.mouseMoved, .leftMouseUp, .leftMouseDragged, .keyDown, .scrollWheel]
    ) { (event) in
        if PauseModel.shared.pause {
            return
        }
        if event.type == .mouseMoved {
            if WindowManager.shared.closeOnlyPopbarWindows(.expanded) {
                lastSelectedText = ""
            }
            eventState.lastMouseEventType = .mouseMoved
        } else if event.type == .scrollWheel {
            lastSelectedText = ""
            WindowManager.shared.closeAllWindows(.original)
        } else {
//            logger.debug("event \(eventTypeMap[event.type]!)  \(eventTypeMap[eventState.lastMouseEventType]!)")
            var updatedSelectedText = false
            if eventState.isSelected(event: event) {
                if let ctx = getSelectedText() {
                    logger.info("SelectedContext \(ctx)")
                    if !ctx.Text.isEmpty {
                        updatedSelectedText = true
                        if lastSelectedText != ctx.Text {
                            lastSelectedText = ctx.Text
                            hoverWorkItem?.cancel()

                            let workItem = DispatchWorkItem {
                                WindowManager.shared.createPopBarWindow(ctx)
                            }
                            hoverWorkItem = workItem
                            let delay = 0.2
                            // 在 0.2 秒后执行
                            // 解决，3 连击选定整行是从 2 连击加一次连击产生的。所以会在短时间内出现2个2次连续鼠标左键释放。
                            // 导致获取选定文本两次，绘制、关闭、再绘制窗口，造成窗口闪烁。
                            // 如果 0.2 秒内再次有点击的话，就取消之前的绘制窗口，这样能避免窗口闪烁。
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                        }
                    }
                }
            }

            if !updatedSelectedText &&
                getBundleID() != SelfBundleID {
                lastSelectedText = ""
                WindowManager.shared.closeAllWindows(.original)
                ChatWindowManager.shared.closeAllWindows(.original)
            }
        }
    }
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
    .keyUp: "keyup",
    .leftMouseUp: "leftMouseUp",
    .leftMouseDragged: "leftMouseDragged",
    .scrollWheel: "scrollWheel"
]

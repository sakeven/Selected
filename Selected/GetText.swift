//
//  GetText.swift
//  Selected
//
//  Created by sake on 2024/2/29.
//

import Cocoa
import SwiftUI
import OpenAI
import Defaults

struct SelectedTextContext {
    var Text: String = ""
    var BundleID: String = ""
    var Editable: Bool = false // 当前窗口是否可编辑。浏览器里的怎么判断？
    // TODO：
    // 1. 浏览器下，获取当前网页的 url
    // 2. IDE 或者 Editor 下，获取当前编辑文件名、行号等
}


let SelfBundleID = Bundle.main.bundleIdentifier ?? "io.kitool.Selected"

func getSelectedTextByAX(bundleID: String) -> String {
    let systemWideElement: AXUIElement = AXUIElementCreateSystemWide()
    var focusedWindow: AnyObject?
    var error: AXError = AXUIElementCopyAttributeValue(systemWideElement,
                                                       kAXFocusedApplicationAttribute as CFString,
                                                       &focusedWindow)
    if error != .success {
        NSLog("Unable to get focused window: \(error)")
        return ""
    }
    
    if let focusedApp = focusedWindow as! AXUIElement? {
        var focusedElement: AnyObject?
        error = AXUIElementCopyAttributeValue(focusedApp,
                                              kAXFocusedUIElementAttribute as CFString,
                                              &focusedElement)
        
        if error == .success, let focusedElement = focusedElement as! AXUIElement? {
                        
            var selectedTextValue: AnyObject?
            error = AXUIElementCopyAttributeValue(focusedElement,
                                                  kAXSelectedTextAttribute as CFString,
                                                  &selectedTextValue)
            if error == .success, let selectedText = selectedTextValue as? String {
                return selectedText
            } else {
                NSLog("Unable to get selected text: \(error)")
            }
        }
    }
    return ""
}

func getUIElementProperties(_ element: AXUIElement) {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
    
    var roleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
    
    if let title = titleValue as? String {
        print("UI element title: \(title)")
    }
    if let role = roleValue as? String {
        print("UI element role: \(role)")
    }
}

func getSelectedText() -> SelectedTextContext? {
    var ctx = SelectedTextContext()
    let bundleID = getBundleID()
    ctx.BundleID = bundleID
    NSLog("bundleID \(bundleID)")
    if bundleID == SelfBundleID {
        return nil
    }
    
    ctx.Editable = isCurrentFocusedElementEditable() ?? false
    
    var selectedText = ""
    if isBrowser(id: bundleID) {
        // 辅助功能也会拿到网页内容，但是可能不够完整。暂时放弃获取地址栏内容
        // 地址栏的内容，无法通过脚本获取，但是可以通过辅助功能获取。
        selectedText = getSelectedTextByAX(bundleID: bundleID)
        NSLog("browser \(selectedText)")
        if selectedText.isEmpty {
            selectedText = getSelectedTextByAppleScript(bundleID: bundleID)
        }
    } else {
        selectedText = getSelectedTextByAX(bundleID: bundleID)
    }
    
    if selectedText.isEmpty && SupportedCmdCAppList.contains(bundleID) {
        NSLog("getSelectedTextBySimulateCommandC")
        selectedText = getSelectedTextBySimulateCommandC()
        if bundleID == "com.apple.iBooksX" {
            // hack for iBooks
            if let index = selectedText.endIndex(of: "\n\n摘录来自\n") {
                selectedText = String(selectedText[..<index])
            }
        }
    }
    
    ctx.Text = selectedText
    return ctx
}

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S) -> Index? {
        let indeics = ranges(of: string).map(\.lowerBound)
        if indeics.count > 0 {
            return indeics[indeics.count-1]
        }
        return nil
    }
}

let SupportedCmdCAppList: [String] = ["com.microsoft.VSCode",
                                      "dev.zed.Zed",
                                      "dev.warp.Warp-Stable",
                                      "com.apple.iBooksX",
                                      "com.tencent.xinWeChat"]

func getSelectedTextBySimulateCommandC() -> String {
    let pboard =  NSPasteboard.general
    let lastCopyText = pboard.string(forType: .string)
    let lastChangeCount = pboard.changeCount
    
    PressCopyKey()
    
    usleep(100000) // sleep 0.1s to wait NSPasteboard get copy string.
    if pboard.changeCount == lastChangeCount {
        // not copied
        return ""
    }
    
    let selectText = pboard.string(forType: .string)
    pboard.clearContents()
    pboard.setString(lastCopyText ?? "", forType: .string)
    return selectText ?? ""
}

func isCurrentFocusedElementEditable() -> Bool? {
    let systemWideElement = AXUIElementCreateSystemWide()
    
    var focusedApp: AnyObject?
    var result = AXUIElementCopyAttributeValue(systemWideElement,
                                               kAXFocusedApplicationAttribute as CFString,
                                               &focusedApp)
    guard result == .success, let axfocusedApp = focusedApp as! AXUIElement? else {
        return nil
    }
    
    // Get the currently focused UI element
    var focusedElement: AnyObject?
    result = AXUIElementCopyAttributeValue(axfocusedApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    guard result == .success, let axFocusedElement = focusedElement as! AXUIElement? else {
        return nil
    }
    
    getUIElementProperties(axFocusedElement)
    
    // Attempt to determine if the element is a text field by checking for a value attribute
    var value: AnyObject?
    let valueResult = AXUIElementCopyAttributeValue(axFocusedElement, kAXValueAttribute as CFString, &value)
    
    // Check if the value attribute exists and potentially editable
    if valueResult == .success, value != nil {
        var isAttributeSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(axFocusedElement, kAXValueAttribute as CFString, &isAttributeSettable)
        return isAttributeSettable.boolValue
    }
    return nil
}


// getBundleID, a frontmost window from other apps may not a fronmost app.
func getBundleID() -> String {
    let systemWideElement = AXUIElementCreateSystemWide()
    
    var focusedApp: AnyObject?
    let result = AXUIElementCopyAttributeValue(systemWideElement,
                                               kAXFocusedApplicationAttribute as CFString,
                                               &focusedApp)
    guard result == .success, let axfocusedApp = focusedApp as! AXUIElement? else {
        // chrome or vscode will return AXError(-25212)
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }
    
    let focusedPid = pidForElement(element: axfocusedApp)
    let runningApp = NSRunningApplication(processIdentifier: focusedPid!)
    return runningApp?.bundleIdentifier ?? ""
}

func pidForElement(element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    let error = AXUIElementGetPid(element, &pid)
    return (error == .success) ? pid : nil
}



func isBrowser(id: String) -> Bool {
    return isChrome(id: id) || isSafari(id: id)
}


func isChrome(id: String)-> Bool {
    let chromeList = [
        "com.google.Chrome",     // Google Chrome
        "com.microsoft.edgemac", // Microsoft Edge
        "company.thebrowser.Browser" // Arc
    ];
    return chromeList.contains(id)
}

func isArc(id: String)-> Bool {
    return "company.thebrowser.Browser"  == id
}

func isSafari(id: String)-> Bool {
    return id == "com.apple.Safari"
}

func getSelectedTextByAppleScript(bundleID: String) -> String{
    if isChrome(id: bundleID) {
        let selected = getSelectedTextByAppleScriptFromChrome(bundleID: bundleID)
        if isArc(id: bundleID) {
            // arc 浏览器获得的文本前后会带双引号，需要去掉。
            return String(String(selected.dropLast(1)).dropFirst(1))
        } else {
            return selected
        }
    } else if isSafari(id: bundleID) {
        return getSelectedTextByAppleScriptFromSafari(bundleID: bundleID)
    }
    
    NSLog("unknown \(bundleID)")
    return ""
}

// 需要开启 Safari 开发者设置中的 “允许 Apple 事件中的 JavaScript”
func getSelectedTextByAppleScriptFromSafari(bundleID: String) -> String{
    // 在应用到 info 里加入 NSAppleEventsUsageDescription 描述，让用户授权就可以执行 apple script 与其它 app 交互
    // 不需要单独建一个 Info.plist，不生效
    NSLog("bundleID: \(bundleID)")
    if let scriptObject =  NSAppleScript(source: """
                  with timeout of 5 seconds
                      tell application id "\(bundleID)"
                        tell front document
                            set selection_text to do JavaScript "window.getSelection().toString();"
                        end tell
                      end tell
                  end timeout
                  """) {
        
        var error: NSDictionary?
        let output = scriptObject.executeAndReturnError(&error)
        if (error != nil) {
            NSLog("error: \(String(describing: error))")
            return ""
        } else {
            return output.stringValue!
        }
    }
    return ""
}


func getSelectedTextByAppleScriptFromChrome(bundleID: String) -> String{
    // 在应用到 info 里加入 NSAppleEventsUsageDescription 描述，让用户授权就可以执行 apple script 与其它 app 交互
    // 不需要单独建一个 Info.plist，不生效
    if let scriptObject =  NSAppleScript(source: """
                  with timeout of 5 seconds
                      tell application id "\(bundleID)"
                         tell active tab of front window
                             set selection_text to execute javascript "window.getSelection().toString();"
                         end tell
                      end tell
                  end timeout
                  """) {
        var error: NSDictionary?
        // TODO timeout?
        let output = scriptObject.executeAndReturnError(&error)
        if (error != nil) {
            NSLog("error: \(String(describing: error))")
            return ""
        } else {
            return output.stringValue ?? ""
        }
    }
    return ""
}

import AppKit

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

struct BroswerSelectedTextContext {
    var url: String
    var text: String
}

func getSelectedTextByAppleScript(bundleID: String) -> BroswerSelectedTextContext?{
    if isChrome(id: bundleID) {
        let selected = getSelectedTextByAppleScriptFromChrome(bundleID: bundleID)
        let url = getChromeCurrentTabURL(bundleID: bundleID)
        if isArc(id: bundleID) {
            // arc 浏览器获得的文本前后会带双引号，需要去掉。
            return BroswerSelectedTextContext(url: url, text: String(String(selected.dropLast(1)).dropFirst(1)))
        }
        return BroswerSelectedTextContext(url: url, text: selected)
    } else if isSafari(id: bundleID) {
        let selected = getSelectedTextByAppleScriptFromSafari(bundleID: bundleID)
        let url = getSafariCurrentTabURL(bundleID: bundleID)
        return BroswerSelectedTextContext(url: url, text: selected)
    }

    logger.debug("unknown \(bundleID)")
    return nil
}

// 需要开启 Safari 开发者设置中的 “允许 Apple 事件中的 JavaScript”
func getSelectedTextByAppleScriptFromSafari(bundleID: String) -> String{
    // 在应用到 info 里加入 NSAppleEventsUsageDescription 描述，让用户授权就可以执行 apple script 与其它 app 交互
    // 不需要单独建一个 Info.plist，不生效
    logger.debug("bundleID: \(bundleID)")
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
            logger.debug("error: \(String(describing: error))")
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
            logger.debug("error: \(String(describing: error))")
            return ""
        } else {
            return output.stringValue ?? ""
        }
    }
    return ""
}


func getSafariCurrentTabURL(bundleID: String) -> String {
    let script = """
tell application id "\(bundleID)"
set theUrl to URL of front document
end tell
"""

    if let scriptObject =  NSAppleScript(source: script) {
        var error: NSDictionary?
        // TODO timeout?
        let output = scriptObject.executeAndReturnError(&error)
        if (error != nil) {
            logger.debug("error: \(String(describing: error))")
            return ""
        } else {
            return output.stringValue ?? ""
        }
    }
    return ""
}


func getChromeCurrentTabURL(bundleID: String) -> String {
    let script = """
tell application id "\(bundleID)"
set theUrl to URL of active tab of front window
end tell
"""

    if let scriptObject =  NSAppleScript(source: script) {
        var error: NSDictionary?
        // TODO timeout?
        let output = scriptObject.executeAndReturnError(&error)
        if (error != nil) {
            logger.debug("error: \(String(describing: error))")
            return ""
        } else {
            return output.stringValue ?? ""
        }
    }
    return ""
}

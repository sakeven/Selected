import AppKit

func getSelectedText() -> SelectedTextContext? {
    var ctx = SelectedTextContext()
    let bundleID = getBundleID()
    ctx.BundleID = bundleID
    logger.debug("bundleID \(bundleID)")
    if bundleID == SelfBundleID {
        return nil
    }

    ctx.Editable = isCurrentFocusedElementEditable() ?? false
    if copyableAppList.contains(bundleID) {
        ctx.Editable = true
    }

    var selectedText = ""
    if isBrowser(id: bundleID) {
        // 辅助功能也会拿到网页内容，但是可能不够完整。暂时放弃获取地址栏内容
        // 地址栏的内容，无法通过脚本获取，但是可以通过辅助功能获取。
        //        selectedText = getSelectedTextByAX(bundleID: bundleID)
        //        print("browser \(selectedText)")
        //        if selectedText.isEmpty {
        if let browserCtx = getSelectedTextByAppleScript(bundleID: bundleID) {
            selectedText = browserCtx.text
            ctx.WebPageURL = browserCtx.url
        }
        //        }
    } else {
        selectedText = getSelectedTextByAX(bundleID: bundleID)
    }

    if selectedText.isEmpty && SupportedCmdCAppList.contains(bundleID) {
        logger.debug("getSelectedTextBySimulateCommandC")
        selectedText = getSelectedTextBySimulateCommandC()
        if bundleID == "com.apple.iBooksX" {
            // hack for iBooks
            if let index = selectedText.endIndex(of: "\n\n摘录来自\n") {
                selectedText = String(selectedText[..<index])
            } else if let index = selectedText.endIndex(of: "\n\nExcerpt From\n") {
                selectedText = String(selectedText[..<index])
            }
        }
    }

    ctx.readDetectedContent(from: selectedText)
    return ctx
}

let SupportedCmdCAppList: [String] = ["com.microsoft.VSCode",
                                      "com.microsoft.onenote.mac",
                                      "com.microsoft.Word",
                                      "com.microsoft.Powerpoint",
                                      "dev.zed.Zed",
                                      "dev.warp.Warp-Stable",
                                      "com.apple.iBooksX",
                                      "ru.keepcoder.Telegram",
                                      "com.laiwang.DingTalk",
                                      "dd.work.exclusive4aliding",
                                      "com.kangfenmao.CherryStudio",
                                      "com.tencent.xinWeChat",

                                      // browsers
                                      "com.apple.Safari",
                                      "com.google.Chrome",     // Google Chrome
                                      "com.microsoft.edgemac", // Microsoft Edge
                                      "company.thebrowser.Browser",  // Arc
]

let copyableAppList: [String] = ["dev.warp.Warp-Stable",
                                 "com.microsoft.onenote.mac",
                                 "com.microsoft.Word",
                                 "com.microsoft.Powerpoint",
                                 "dev.zed.Zed"]

func getSelectedTextBySimulateCommandC() -> String {
    let pboard =  NSPasteboard.general
    let lastCopyText = pboard.string(forType: .string)
    let lastChangeCount = pboard.changeCount

    let id = UUID().uuidString
    ClipService.shared.pauseMonitor(id)
    defer {ClipService.shared.resumeMonitor(id)}

    logger.debug("changeCount PressCopyKey \(id)")

    PressCopyKey()

    usleep(100000) // sleep 0.1s to wait NSPasteboard get copy string.
    if pboard.changeCount == lastChangeCount {
        // not copied
        return ""
    }

    let selectText = pboard.string(forType: .string)
    logger.debug("changeCount a \(pboard.changeCount)")
    pboard.clearContents()
    logger.debug("last content: \(String(describing: lastCopyText))")
    pboard.setString(lastCopyText ?? "", forType: .string)
    logger.debug("changeCount b \(pboard.changeCount)")

    return selectText ?? ""
}

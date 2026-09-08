import AppKit

// pasteTextBefore: When there is a text selection, the cursor will move forward, then insert the text, which is equivalent to inserting the text before the currently seleted text.
// Note that some applications dot not support this operation and always insert the text after the currently selected text, such as Terminal.
func pasteTextBefore(_ text: String) {
    PressKey(keycode: Keycode.leftArrow)
    pasteText(text)
}

// pasteTextAfter: When there is a text selection, the cursor will move backward, then insert the text, which is equivalent to inserting the text after the currently seleted text.
// Note that some applications dot not support this operation and always insert the text after the currently selected text, such as Terminal.
func pasteTextAfter(_ text: String) {
    PressKey(keycode: Keycode.rightArrow)
    pasteText(text)
}


func pasteText(_ text: String) {
    let id = UUID().uuidString
    ClipService.shared.pauseMonitor(id)
    defer {
        ClipService.shared.resumeMonitor(id)
    }
    let pasteboard = NSPasteboard.general
    let previousItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
        let saved = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) { saved.setData(data, forType: type) }
        }
        return saved
    } ?? []

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    let temporaryChangeCount = pasteboard.changeCount
    PressPasteKey()
    usleep(100000)
    if pasteboard.changeCount == temporaryChangeCount {
        pasteboard.clearContents()
        pasteboard.writeObjects(previousItems)
    }
}

func copyText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

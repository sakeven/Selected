import AppKit

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

import AppKit

// 监听鼠标移动
func monitorMouseMove() {
    guard AppRuntimeMode.current == .normal else { return }
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

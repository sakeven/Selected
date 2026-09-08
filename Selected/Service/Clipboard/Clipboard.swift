//
//  Clipboard.swift
//  Selected
//
//  Created by sake on 2024/3/31.
//

import Foundation
import Cocoa
import Defaults

class ClipService {
    static let shared = ClipService()

    private var eventMonitor: Any?
    private let pasteboard: NSPasteboard

    //
    private var lock = NSLock()
    private var changeCount: Int = 0
    private var skip = false

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        guard AppRuntimeMode.current == .normal else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            guard Defaults[.enableClipboard] else { return }

            //            AppLogger.clipboard.debug("pasteboard event \(eventTypeMap[event.type]!)")

            if skip {
                return
            }

            let eventType = event.type
            DispatchQueue.global(qos: .background).async {
                if eventType == .leftMouseUp {
                    // 如果是鼠标右键菜单栏里左键点击复制的话，需要等半秒才能从 pasteboard 里获取到复制的数据。
                    usleep(500000)
                }
                self.checkPasteboard()
            }
        }
    }

    func pauseMonitor(_ id: String) {
        lock.lock()
        AppLogger.clipboard.debug("pasteboard \(id) pauseMonitor changeCount \(self.changeCount)")
        skip = true
        lock.unlock()
    }

    func resumeMonitor(_ id: String) {
        lock.lock()
        skip = false
        changeCount = pasteboard.changeCount
        AppLogger.clipboard.debug("pasteboard \(id) resumeMonitor changeCount \(self.changeCount)")
        lock.unlock()
    }

    func restore(_ item: ClipHistoryData, completing: () -> Void) {
        let id = UUID().uuidString
        pauseMonitor(id)
        defer { resumeMonitor(id) }

        pasteboard.clearContents()
        for content in item.getItems() {
            pasteboard.setData(content.data, forType: NSPasteboard.PasteboardType(rawValue: content.type!))
        }
        PersistenceController.shared.updateClipHistoryData(item)

        completing()
    }

    private func checkPasteboard() {
        lock.lock()
        defer {
            lock.unlock()
        }

        let currentChangeCount = pasteboard.changeCount
        if changeCount == currentChangeCount {
            return
        }
        changeCount = currentChangeCount
        AppLogger.clipboard.debug("pasteboard changeCount \(self.changeCount)")

        guard pasteboard.types != nil else {
            return
        }

        // 剪贴板内容发生变化，处理变化
        AppLogger.clipboard.debug("pasteboard \(String(describing: self.pasteboard.types))")
        guard let clipData = ClipData(pasteboard: pasteboard) else {
            return
        }

        if skip {
            return
        }
        if clipData.types.isEmpty {
            return
        }
        if filterClipData(clipData) {
            return
        }
        PersistenceController.shared.store(clipData)
    }
}

private var excludeApplications = [
    "com.agilebits.onepassword",
    "com.agilebits.onepassword-osx",
    "com.agilebits.onepassword7",
    "com.agilebits.onepassword4"]

private func filterClipData(_ clipData: ClipData) -> Bool{
    if excludeApplications.contains(clipData.appBundleID) {
        return true
    }
    return false
}

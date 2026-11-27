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
    private let persistence: PersistenceController
    private let monitorQueue = DispatchQueue(label: "Selected.ClipboardMonitor", qos: .utility)

    private let lock = NSLock()
    private var changeCount: Int = 0
    private var skip = false

    init(pasteboard: NSPasteboard = .general, persistence: PersistenceController = .shared) {
        self.pasteboard = pasteboard
        self.persistence = persistence
        changeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        guard AppRuntimeMode.current == .normal else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            guard Defaults[.enableClipboard] else { return }

            // A menu click may arrive before its Copy action has populated the pasteboard.
            let delay: DispatchTimeInterval = event.type == .leftMouseUp ? .milliseconds(500) : .milliseconds(0)
            monitorQueue.asyncAfter(deadline: .now() + delay) {
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
        let restored = NSPasteboardItem()
        for content in item.getItems() {
            guard let type = content.type, let data = content.data else { continue }
            restored.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
        guard !restored.types.isEmpty else { return }

        let id = UUID().uuidString
        pauseMonitor(id)
        defer { resumeMonitor(id) }

        pasteboard.clearContents()
        guard pasteboard.writeObjects([restored]) else { return }
        persistence.updateClipHistoryData(item)

        completing()
    }

    func checkPasteboard() {
        let countToRead: Int? = lock.withLock {
            let count = pasteboard.changeCount
            guard !skip, changeCount != count else { return nil }
            changeCount = count
            return count
        }
        guard let countToRead, let clipData = ClipData(pasteboard: pasteboard),
              !clipData.items.isEmpty, !filterClipData(clipData) else { return }

        lock.withLock {
            guard !skip, changeCount == countToRead, pasteboard.changeCount == countToRead else { return }
            persistence.store(clipData)
        }
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

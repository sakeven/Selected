import SwiftUI

class ClipWindowManager {
    static let shared =  ClipWindowManager()

    private(set) var actionTarget: ActionTarget?

    private var lock = NSLock()
    private var windowCtr: ClipWindowController?
    private var mouseMonitor: Any?

    func startMonitoring() {
        guard AppRuntimeMode.current == .normal, mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            _ = self?.closeWindow()
        }
    }

    deinit {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }

    func restore(_ item: ClipHistoryData, paste: Bool) {
        ClipService.shared.restore(item) {
            if paste {
                resignKey()
                PressPasteKey()
            }
            forceCloseWindow()
        }
    }

    func createWindow() {
        lock.lock()
        defer{
            lock.unlock()
        }
        windowCtr?.close()
        actionTarget = MainActor.assumeIsolated { ActionTarget() }
        let view = ClipView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        let window = ClipWindowController(rootView: AnyView(view))
        windowCtr = window
        window.showWindow(nil)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window.window, queue: nil) { _ in
            self.windowCtr = nil
        }
        return
    }

    func closeWindow() -> Bool {
        lock.lock()
        defer{
            lock.unlock()
        }

        guard let windowCtr = windowCtr else {
            return true
        }
        guard let window = windowCtr.window else {
            return true
        }
        var closed = false
        if !window.frame.contains(NSEvent.mouseLocation){
            windowCtr.close()
            closed = true
            self.windowCtr = nil
        }
        return closed
    }

    func resignKey(){
        lock.lock()
        defer{
            lock.unlock()
        }
        windowCtr?.window?.resignKey()
    }

    func forceCloseWindow() {
        lock.lock()
        defer{
            lock.unlock()
        }
        guard let windowCtr = windowCtr else {
            return
        }
        windowCtr.close()
        self.windowCtr = nil
    }
}

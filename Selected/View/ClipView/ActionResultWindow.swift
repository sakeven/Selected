import AppKit
import SwiftUI

@MainActor final class ActionResultWindow: NSObject, NSWindowDelegate {
    static let shared = ActionResultWindow()
    private var controller: NSWindowController?
    private var session: ActionSession?

    func show(_ session: ActionSession) {
        close()
        self.session = session
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 480), backing: .buffered, defer: false, key: true)
        panel.level = .floating
        panel.title = session.request.title
        panel.contentView = NSHostingView(rootView: ActionResultView(session: session) { [weak self] in self?.close() })
        panel.minSize = NSSize(width: 560, height: 410)
        panel.delegate = self
        panel.center()
        controller = NSWindowController(window: panel)
        panel.makeKeyAndOrderFront(nil)
        session.run()
    }

    func close() {
        session?.cancel()
        controller?.close()
        controller = nil
        session = nil
    }

    func windowWillClose(_ notification: Notification) { session?.cancel() }
}

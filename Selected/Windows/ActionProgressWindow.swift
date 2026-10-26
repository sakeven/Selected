import AppKit
import SwiftUI

@MainActor final class ActionProgressWindowController: BaseWindowController {
    let session: ActionSession

    init(session: ActionSession, at point: NSPoint) {
        self.session = session
        super.init(rootView: AnyView(ActionProgressView(session: session)), windowType: .text,
                   positionStrategy: .nearPoint(point), size: .zero)
        window?.title = session.request.title
        window?.identifier = NSUserInterfaceItemIdentifier("action-progress")
        window?.styleMask.remove(.resizable)
        window?.hidesOnDeactivate = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func canClose() -> Bool { !session.isRunning }

    func windowWillClose(_ notification: Notification) { session.cancel() }
}

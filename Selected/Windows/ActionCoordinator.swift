import AppKit

@MainActor
enum ActionCoordinator {
    static func perform(_ request: ActionRequest, input: ActionInput, target: ActionTarget, original: ActionInput? = nil, originalContent: ClipAIContent? = nil,
                            resultPosition: NSPoint = NSEvent.mouseLocation) {
        let session = ActionSession(input: request.captureInput(input), request: request, target: target, original: original, originalContent: originalContent)
        ClipWindowManager.shared.forceCloseWindow()
        _ = WindowManager.shared.closeOnlyPopbarWindows(.force)
        if request.output == .xshow || (request.output == .show && input.source == .clipboard) {
            ActionResultWindow.shared.show(session)
        } else {
            Task {
                await session.run().value
                if session.failed {
                    let message = session.output.isEmpty ? session.message : session.message + "\n\n" + session.output
                    WindowManager.shared.createTextWindow(message, editable: false, at: resultPosition)
                } else if request.output == .show {
                    WindowManager.shared.createTextWindow(session.output.isEmpty ? session.message : session.output,
                                                          editable: false, at: resultPosition)
                }
            }
        }
    }
}

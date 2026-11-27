import AppKit

@MainActor
final class SelectionMonitor {
    private let windows: WindowManager
    private let readSelection: () -> SelectedTextContext?
    private var events = EventState()

    init(windows: WindowManager, readSelection: @escaping () -> SelectedTextContext? = getSelectedText) {
        self.windows = windows
        self.readSelection = readSelection
    }

    func start() {
        guard AppRuntimeMode.current == .normal else { return }
        let sharedEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        NSEvent.addGlobalMonitorForEvents(matching: sharedEvents.union([.leftMouseDragged, .leftMouseUp])) { event in
            self.handle(event, local: false)
        }
        NSEvent.addLocalMonitorForEvents(matching: sharedEvents) { event in
            self.handle(event, local: true)
            return event
        }
    }

    func handle(_ event: NSEvent, local: Bool) {
        guard !PauseModel.shared.pause else { return }
        switch event.type {
        case .mouseMoved:
            events.lastMouseEventType = .mouseMoved
            windows.closeOnlyPopbarWindows(.expanded)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // Keep consecutive left mouse-ups eligible for double and triple clicks.
            if event.type != .leftMouseDown { events.lastMouseEventType = event.type }
            if !local || !(event.window?.windowController is PopBarWindowController) {
                windows.closeOnlyPopbarWindows(.force)
            }
        case .scrollWheel:
            events.lastMouseEventType = .scrollWheel
            if local {
                windows.closeOnlyPopbarWindows(.original)
            } else {
                windows.closeAllWindows(.original)
            }
        default:
            // The selection reader posts its own Command-C in apps without accessible selected text.
            if event.type == .keyDown, event.keyCode == Keycode.c, event.modifierFlags.contains(.command),
               event.cgEvent?.getIntegerValueField(.eventSourceUserData) == selectionCopyEventTag { return }
            if local {
                windows.closeOnlyPopbarWindows(.force)
                return
            }
            let releasePoint = event.type == .leftMouseUp ? event.cgEvent?.unflippedLocation : nil
            let point = releasePoint ?? windows.mouseLocation()
            if events.isSelected(event: event), let ctx = readSelection(), !ctx.Text.isEmpty {
                logger.info("SelectedContext \(ctx)")
                windows.schedulePopBar(ctx, at: point)
                return
            }
            windows.closeOnlyPopbarWindows(.force)
            if getBundleID() != SelfBundleID {
                windows.closeAllWindows(.original)
                ChatWindowManager.shared.closeAllWindows(.original)
            }
        }
    }
}

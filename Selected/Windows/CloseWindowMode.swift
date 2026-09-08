import AppKit

enum CloseWindowMode {
    case expanded
    case original
    case force

    func shouldClose(frame: NSRect, mouseLocation: NSPoint) -> Bool {
        switch self {
        case .expanded:
            return !frame.insetBy(dx: -kExpandedLength, dy: -kExpandedLength).contains(mouseLocation)
        case .original:
            return !frame.contains(mouseLocation)
        case .force:
            return true
        }
    }
}

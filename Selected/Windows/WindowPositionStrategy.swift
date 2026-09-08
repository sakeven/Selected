import AppKit

enum WindowPositionStrategy {
    case centerScreen
    case nearPoint(NSPoint)
    case centerScreenOffset(CGFloat)

    func origin(windowFrame: NSRect, requestedSize: NSSize, screenFrame: NSRect) -> NSPoint {
        switch self {
        case .centerScreen:
            return centeredOrigin(windowFrame: windowFrame, requestedSize: requestedSize, screenFrame: screenFrame, verticalFactor: 0.5)
        case .centerScreenOffset(let factor):
            return centeredOrigin(windowFrame: windowFrame, requestedSize: requestedSize, screenFrame: screenFrame, verticalFactor: factor)
        case .nearPoint(let point):
            let x = min(screenFrame.maxX - windowFrame.width, max(point.x - windowFrame.width / 2, screenFrame.minX))
            var y = point.y + 18
            if y + windowFrame.height > screenFrame.maxY {
                y = point.y - windowFrame.height - 18
            }
            y = max(screenFrame.minY, min(y, screenFrame.maxY - windowFrame.height))
            return NSPoint(x: x, y: y)
        }
    }

    private func centeredOrigin(windowFrame: NSRect, requestedSize: NSSize, screenFrame: NSRect, verticalFactor: CGFloat) -> NSPoint {
        let width = windowFrame.width == 0 ? requestedSize.width : windowFrame.width
        let height = windowFrame.height == 0 ? requestedSize.height : windowFrame.height
        return NSPoint(x: (screenFrame.width - width) / 2 + screenFrame.origin.x,
                       y: (screenFrame.height - height) * verticalFactor + screenFrame.origin.y)
    }
}

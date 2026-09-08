import AppKit

func decodeNSColor(from data: Data) -> NSColor? {
    NSColor(pasteboardPropertyList: data, ofType: .color)
}

func colorToData(color: NSColor) -> Data? {
    do {
        return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    } catch {
        logger.error("convert color to Data: \(error)")
        return nil
    }
}

func swiftUIColor(from c1: NSColor) -> NSColor {
    let count = c1.numberOfComponents
    var rawComponents = Array<CGFloat>(repeating: 0, count: count)

    c1.getComponents(&rawComponents)

    let normalizedComponents = rawComponents.map { $0 > 1.0 ? $0 / 255.0 : $0 }

    let correctedColor = NSColor(
        colorSpace: c1.colorSpace,
        components: normalizedComponents,
        count: normalizedComponents.count
    )

    if let sRGBColor = correctedColor.usingColorSpace(.sRGB) {
        return sRGBColor
    }
    return c1
}

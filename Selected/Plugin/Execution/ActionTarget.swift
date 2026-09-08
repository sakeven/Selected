import AppKit

@MainActor final class ActionTarget {
    let application: NSRunningApplication?
    private let element: AXUIElement?
    private let originalValue: String?
    private let originalRange: CFRange?
    private var insertedValue: String?
    private var insertedRange: CFRange?

    init(application: NSRunningApplication? = NSWorkspace.shared.frontmostApplication) {
        self.application = application?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : application
        var focused: CFTypeRef?
        if let application = self.application {
            AXUIElementCopyAttributeValue(AXUIElementCreateApplication(application.processIdentifier), kAXFocusedUIElementAttribute as CFString, &focused)
        }
        element = focused.map { $0 as! AXUIElement }
        originalValue = Self.value(element)
        var selectedRange: CFTypeRef?
        var range = CFRange()
        if let element,
           AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success,
           let selectedRange, CFGetTypeID(selectedRange) == AXValueGetTypeID(),
           AXValueGetValue(selectedRange as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0,
           range.location <= (originalValue as NSString?)?.length ?? 0,
           range.length <= ((originalValue as NSString?)?.length ?? 0) - range.location {
            originalRange = range
        } else { originalRange = nil }
    }

    var name: String { application?.localizedName ?? String(localized: "Original app") }
    var isAvailable: Bool { application != nil && application?.isTerminated == false }
    var canReplace: Bool { originalValue != nil && (originalRange?.length ?? 0) > 0 }
    var canRestore: Bool { insertedValue != nil }

    func activate() async throws {
        guard AXIsProcessTrusted() else {
            throw PluginValidationError(messages: [String(localized: "Enable Accessibility access for Selected in System Settings to paste into other apps.")])
        }
        guard let application, !application.isTerminated else {
            throw PluginValidationError(messages: [String(localized: "The original app is no longer available. Copy the result instead.")])
        }
        NSApp.keyWindow?.resignKey()
        application.activate()
        try await Task.sleep(for: .milliseconds(180))
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
            throw PluginValidationError(messages: [String(localized: "Could not focus the original app. Try again or copy the result.")])
        }
    }

    func paste(_ text: String, replacing: Bool = false) async throws {
        try await activate()
        let previousValue = insertedValue ?? originalValue
        let previousRange = insertedRange ?? originalRange
        if replacing {
            guard let element, let previousValue, let previousRange, Self.value(element) == previousValue else {
                throw PluginValidationError(messages: [String(localized: "The original text has changed. Copy the result or paste at the current cursor.")])
            }
            try focus(element, range: previousRange)
        }
        pasteText(text)
        insertedValue = nil
        insertedRange = nil
        if replacing, let previousValue, let previousRange {
            let range = NSRange(location: previousRange.location, length: previousRange.length)
            let expected = (previousValue as NSString).replacingCharacters(in: range, with: text)
            try await Task.sleep(for: .milliseconds(150))
            if Self.value(element) == expected {
                insertedValue = expected
                insertedRange = CFRange(location: range.location, length: (text as NSString).length)
            } else {
                throw PluginValidationError(messages: [String(localized: "Paste was sent, but the replacement could not be verified. Check the original app.")])
            }
        }
    }

    func restore() async throws {
        guard let element, let insertedValue, let insertedRange, let originalValue, let originalRange,
              Self.value(element) == insertedValue else {
            throw PluginValidationError(messages: [String(localized: "The text has changed since replacement. The original is still available to copy.")])
        }
        try await activate()
        guard Self.value(element) == insertedValue else {
            throw PluginValidationError(messages: [String(localized: "The text has changed since replacement. The original is still available to copy.")])
        }
        try focus(element, range: insertedRange)
        pasteText((originalValue as NSString).substring(with: NSRange(location: originalRange.location, length: originalRange.length)))
        try await Task.sleep(for: .milliseconds(150))
        guard Self.value(element) == originalValue else {
            throw PluginValidationError(messages: [String(localized: "The original text could not be verified after restoring. Check the original app.")])
        }
        self.insertedValue = nil
        self.insertedRange = nil
    }

    private func focus(_ element: AXUIElement, range: CFRange) throws {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        var focused: CFTypeRef?
        if let application {
            AXUIElementCopyAttributeValue(AXUIElementCreateApplication(application.processIdentifier), kAXFocusedUIElementAttribute as CFString, &focused)
        }
        var range = range
        guard let focused, CFEqual(focused, element), let value = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success else {
            throw PluginValidationError(messages: [String(localized: "This app cannot restore the selection. Paste at the current cursor instead.")])
        }
    }

    private static func value(_ element: AXUIElement?) -> String? {
        guard let element else { return nil }
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        return value as? String
    }
}

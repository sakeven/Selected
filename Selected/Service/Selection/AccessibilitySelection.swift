import AppKit

func getSelectedTextByAX(bundleID: String) -> String {
    let systemWideElement: AXUIElement = AXUIElementCreateSystemWide()
    var focusedWindow: AnyObject?
    var error: AXError = AXUIElementCopyAttributeValue(systemWideElement,
                                                       kAXFocusedApplicationAttribute as CFString,
                                                       &focusedWindow)
    if error != .success {
        logger.error("Unable to get focused window: \(String(describing: error))")
        return ""
    }

    if let focusedApp = focusedWindow as! AXUIElement? {
        var focusedElement: AnyObject?
        error = AXUIElementCopyAttributeValue(focusedApp,
                                              kAXFocusedUIElementAttribute as CFString,
                                              &focusedElement)

        if error == .success, let focusedElement = focusedElement as! AXUIElement? {

            var selectedTextValue: AnyObject?
            error = AXUIElementCopyAttributeValue(focusedElement,
                                                  kAXSelectedTextAttribute as CFString,
                                                  &selectedTextValue)
            if error == .success, let selectedText = selectedTextValue as? String {
                return selectedText
            } else {
                logger.error("Unable to get selected text: \(String(describing: error))")
            }
        }
    }
    return ""
}

func getUIElementProperties(_ element: AXUIElement) -> String? {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)

    var roleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)

    if let title = titleValue as? String {
        logger.debug("UI element title: \(title)")
    }
    if let role = roleValue as? String {
        logger.debug("UI element role: \(role)")
        return role
    }
    return nil
}

func isCurrentFocusedElementEditable() -> Bool? {
    let systemWideElement = AXUIElementCreateSystemWide()

    var focusedApp: AnyObject?
    var result = AXUIElementCopyAttributeValue(systemWideElement,
                                               kAXFocusedApplicationAttribute as CFString,
                                               &focusedApp)
    guard result == .success, let axfocusedApp = focusedApp as! AXUIElement? else {
        return nil
    }

    // Get the currently focused UI element
    var focusedElement: AnyObject?
    result = AXUIElementCopyAttributeValue(axfocusedApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    guard result == .success, let axFocusedElement = focusedElement as! AXUIElement? else {
        return nil
    }

    if let role = getUIElementProperties(axFocusedElement) {
        if role == "AXTextArea" {
            return true
        }
    }

    // Attempt to determine if the element is a text field by checking for a value attribute
    var value: AnyObject?
    let valueResult = AXUIElementCopyAttributeValue(axFocusedElement, kAXValueAttribute as CFString, &value)

    // Check if the value attribute exists and potentially editable
    if valueResult == .success, value != nil {
        var isAttributeSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(axFocusedElement, kAXValueAttribute as CFString, &isAttributeSettable)
        logger.debug("editable \(isAttributeSettable.boolValue)")
        return isAttributeSettable.boolValue
    }
    return nil
}


// getBundleID, a frontmost window from other apps may not a fronmost app.
func getBundleID() -> String {
    let systemWideElement = AXUIElementCreateSystemWide()

    var focusedApp: AnyObject?
    let result = AXUIElementCopyAttributeValue(systemWideElement,
                                               kAXFocusedApplicationAttribute as CFString,
                                               &focusedApp)
    guard result == .success, let axfocusedApp = focusedApp as! AXUIElement? else {
        // chrome or vscode will return AXError(-25212)
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }

    let focusedPid = pidForElement(element: axfocusedApp)
    let runningApp = NSRunningApplication(processIdentifier: focusedPid!)
    return runningApp?.bundleIdentifier ?? ""
}

func pidForElement(element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    let error = AXUIElementGetPid(element, &pid)
    return (error == .success) ? pid : nil
}

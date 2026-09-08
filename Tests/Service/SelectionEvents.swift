import AppKit
import Testing
@testable import Selected

struct SelectionEventTests {
    @Test func doubleClickThresholdAndDraggingStayUnchanged() throws {
        var state = EventState()
        #expect(!state.isSelected(event: try mouse(.leftMouseUp, at: 10)))
        #expect(state.isSelected(event: try mouse(.leftMouseUp, at: 10.49)))
        #expect(!state.isSelected(event: try mouse(.leftMouseUp, at: 10.99)))
        #expect(!state.isSelected(event: try mouse(.leftMouseDragged, at: 11)))
        #expect(state.isSelected(event: try mouse(.leftMouseUp, at: 12)))
    }

    @Test func mouseMovementBreaksClickSequenceAndKeysKeepMouseState() throws {
        var state = EventState()
        _ = state.isSelected(event: try mouse(.leftMouseUp, at: 10))
        _ = state.isSelected(event: try mouse(.mouseMoved, at: 10.1))
        #expect(!state.isSelected(event: try mouse(.leftMouseUp, at: 10.2)))
        _ = state.isSelected(event: try mouse(.leftMouseDragged, at: 11))
        _ = state.isSelected(event: try key(Keycode.b, flags: []))
        #expect(state.lastMouseEventType == .leftMouseDragged)
        #expect(state.isSelected(event: try mouse(.leftMouseUp, at: 12)))
    }

    @Test func keyboardSelectionKeepsModifierRules() throws {
        var state = EventState()
        #expect(state.isSelected(event: try key(Keycode.a, flags: .command)))
        #expect(state.isSelected(event: try key(Keycode.a, flags: [.command, .option])))
        #expect(!state.isSelected(event: try key(Keycode.a, flags: [.command, .shift])))
        #expect(!state.isSelected(event: try key(Keycode.a, flags: [.command, .control])))
        #expect(!state.isSelected(event: try key(Keycode.a, flags: [])))
        for code in [Keycode.leftArrow, Keycode.rightArrow, Keycode.upArrow, Keycode.downArrow] {
            #expect(state.isSelected(event: try key(code, flags: [.command, .shift])))
            #expect(state.isSelected(event: try key(code, flags: [.command, .shift, .option])))
            #expect(!state.isSelected(event: try key(code, flags: .shift)))
        }
    }

    @Test func textDetectionPreservesRawLinksAndDeduplicatesThem() {
        var context = SelectedTextContext(BundleID: "test", WebPageURL: "https://source.com", Editable: true)
        let text = "Visit https://example.com and https://example.com or http://other.org."
        context.readDetectedContent(from: text)
        #expect(context.Text == text)
        #expect(Set(context.URLs) == ["https://example.com", "http://other.org"])
        #expect(context.BundleID == "test")
        #expect(context.WebPageURL == "https://source.com")
        #expect(context.Editable)
        #expect(context.Address.isEmpty)
    }

    @Test func bookExcerptMarkerUsesLastMatchStart() {
        let text = "first\n\nExcerpt From\nsecond\n\nExcerpt From\nsource"
        let index = text.endIndex(of: "\n\nExcerpt From\n")
        #expect(index.map { String(text[..<$0]) } == "first\n\nExcerpt From\nsecond")
        #expect(text.endIndex(of: "missing") == nil)
    }

    @Test func browserIdentificationKeepsExistingSupportedApps() {
        for id in ["com.google.Chrome", "com.microsoft.edgemac", "company.thebrowser.Browser", "com.apple.Safari"] {
            #expect(isBrowser(id: id))
        }
        #expect(isArc(id: "company.thebrowser.Browser"))
        #expect(!isChrome(id: "com.apple.Safari"))
        #expect(!isBrowser(id: "org.mozilla.firefox"))
        #expect(!isBrowser(id: ""))
    }

    private func mouse(_ type: NSEvent.EventType, at timestamp: TimeInterval) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: timestamp, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
    }

    private func key(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode))
    }
}

import AppKit
import Testing
@testable import Selected

struct KeyboardTests {
    @Test func combinesModifiersAndResolvesNamedKeys() {
        let combination = KeyCombination("cmd shift option c")
        #expect(combination.keycode == Keycode.c)
        #expect(combination.flags == [.maskCommand, .maskShift, .maskAlternate])
        #expect(KeyCombination("ctr alt f12").flags == [.maskControl, .maskAlternate])
        #expect(KeyCombination("ctr alt f12").keycode == Keycode.f12)
        #expect(KeyCombination("fn caps return").flags == [.maskSecondaryFn, .maskAlphaShift])
        #expect(KeyCombination("fn caps return").keycode == Keycode.returnKey)
    }

    @Test func retainsWhitespaceUnknownTokenAndLastKeyBehavior() {
        #expect(KeyCombination("  cmd   cmd  a b  ").flags == .maskCommand)
        #expect(KeyCombination("  cmd   cmd  a b  ").keycode == Keycode.b)
        #expect(KeyCombination("CMD unknown").flags.isEmpty)
        #expect(KeyCombination("CMD unknown").keycode == 0)
        #expect(KeyCombination("").keycode == 0)
        #expect(KeyCombination("cmd\tc").flags.isEmpty)
    }

}

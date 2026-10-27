import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class AudioPlayerLayoutTests: XCTestCase {
    func testPlaybackControlsRespondToSpaceAndEscape() async throws {
        let session = SpeechSession()
        let data = try speechFixture(duration: 8)
        session.start(text: "Keyboard playback", voice: "Sage") { data }
        try await waitForSpeech(session, phase: .playing)
        session.togglePlayback()
        let controller = TTSWindowController(session: session) { session.stop() }
        defer { controller.close() }
        let window = try XCTUnwrap(controller.window)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(200))
        sendKey(" ", code: 49, to: window)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(session.phase, .playing)
        sendKey(" ", code: 49, to: window)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(session.phase, .paused)
        sendKey("\u{1b}", code: 53, to: window)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(session.phase, .idle)
    }

    private func sendKey(_ characters: String, code: UInt16, to window: NSWindow) {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                    windowNumber: window.windowNumber, context: nil, characters: characters,
                                    charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
        window.sendEvent(event)
    }

    func testSpeechCardStatesInLightAndDarkAppearance() async throws {
        let session = SpeechSession()
        defer { session.stop() }
        let text = "设计的价值，是让每一次操作都自然、清晰。好的界面不需要解释，也不会让人等待时失去方向。"
        for scheme in [ColorScheme.light, .dark] {
            session.start(text: text, voice: "Sage") {
                try await Task.sleep(for: .seconds(30))
                return Data()
            }
            try await capture(session, state: "generating", scheme: scheme)
            session.start(text: text, voice: "Sage") { throw URLError(.notConnectedToInternet) }
            try await waitForSpeech(session, phase: .failed)
            try await capture(session, state: "failed", scheme: scheme)
            let data = try speechFixture(duration: 8, waveform: true)
            session.start(text: text, voice: "Sage") { data }
            try await waitForSpeech(session, phase: .playing)
            session.togglePlayback()
            session.seek(to: 3)
            try await capture(session, state: "paused", scheme: scheme)
        }
    }

    private func capture(_ session: SpeechSession, state: String, scheme: ColorScheme) async throws {
        let host = NSHostingView(rootView: AudioPlayerView(session: session, onClose: {})
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "zh-Hans")))
        let size = host.fittingSize
        XCTAssertEqual(size.width, 440)
        XCTAssertLessThan(size.height, 210)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(400))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        let attachment = XCTAttachment(image: image)
        attachment.name = "speech-\(state)-\(scheme == .light ? "light" : "dark")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

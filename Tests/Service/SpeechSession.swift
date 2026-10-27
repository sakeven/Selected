import AVFoundation
import Testing
@testable import Selected

@Suite(.serialized) @MainActor
struct SpeechSessionTests {
    @Test func generationIsVisibleThenPlaybackCanPauseSeekAndReplay() async throws {
        let session = SpeechSession()
        defer { session.stop() }
        let data = try speechFixture()
        session.start(text: "A short\n passage", voice: "Sage") { data }
        #expect(session.phase == .generating)
        #expect(session.excerpt == "A short passage")
        try await waitForSpeech(session, phase: .playing)
        #expect(abs(session.duration - 1) < 0.001)
        session.togglePlayback()
        #expect(session.phase == .paused)
        session.seek(to: 0.4)
        #expect(session.currentTime == 0.4)
        session.seek(to: -1)
        #expect(session.currentTime == 0)
        session.seek(to: 2)
        #expect(session.currentTime == 1)
        session.togglePlayback()
        #expect(session.phase == .playing)
        #expect(session.currentTime == 0)
        try await waitForSpeech(session, phase: .finished)
        #expect(session.currentTime == session.duration)
        session.togglePlayback()
        #expect(session.phase == .playing)
        #expect(session.currentTime == 0)
    }

    @Test func cancelledAndReplacedRequestsCannotStartLatePlayback() async throws {
        let session = SpeechSession()
        defer { session.stop() }
        let data = try speechFixture()
        var pending: CheckedContinuation<Data, Never>?
        session.start(text: "Old selection", voice: "Sage") {
            await withCheckedContinuation { pending = $0 }
        }
        while pending == nil { await Task.yield() }
        session.start(text: "New selection", voice: "Coral") { data }
        try await waitForSpeech(session, phase: .playing)
        let url = session.audioURL
        pending?.resume(returning: data)
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.text == "New selection")
        #expect(session.voice == "Coral")
        #expect(session.audioURL == url)
        session.stop()
        #expect(session.phase == .idle)
        #expect(session.audioURL == nil)
        #expect(!FileManager.default.fileExists(atPath: try #require(url).path))

        pending = nil
        session.start(text: "Cancelled selection", voice: "Sage") {
            await withCheckedContinuation { pending = $0 }
        }
        while pending == nil { await Task.yield() }
        session.stop()
        pending?.resume(returning: data)
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.phase == .idle)
        #expect(session.audioURL == nil)
    }

    @Test func failureCanRetryAndSavingDoesNotConsumeThePlayingFile() async throws {
        let session = SpeechSession()
        defer { session.stop() }
        let data = try speechFixture()
        var attempts = 0
        session.start(text: "Retry me", voice: "Sage") {
            attempts += 1
            if attempts == 1 { throw URLError(.notConnectedToInternet) }
            return data
        }
        try await waitForSpeech(session, phase: .failed)
        #expect(session.errorMessage != nil)
        #expect(session.audioURL == nil)
        session.togglePlayback()
        #expect(session.phase == .generating)
        try await waitForSpeech(session, phase: .playing)
        session.togglePlayback()
        let source = try #require(session.audioURL)
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        session.save(to: directory)
        let saved = try #require(session.savedURL)
        #expect(try Data(contentsOf: saved) == data)
        #expect(FileManager.default.fileExists(atPath: source.path))
        session.save(to: directory)
        #expect(session.saveError == nil)
        session.stop()
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: saved.path))
    }

    @Test func malformedAudioAndSaveFailuresRemainVisible() async throws {
        let session = SpeechSession()
        defer { session.stop() }
        session.start(text: "Invalid audio", voice: "Sage") { Data("not audio".utf8) }
        try await waitForSpeech(session, phase: .failed)
        #expect(session.errorMessage != nil)
        #expect(session.audioURL == nil)
        let data = try speechFixture()
        session.start(text: "Valid audio", voice: "Sage") { data }
        try await waitForSpeech(session, phase: .playing)
        session.togglePlayback()
        let source = try #require(session.audioURL)
        session.save(to: source)
        #expect(session.saveError != nil)
        #expect(session.phase == .paused)
        #expect(session.savedURL == nil)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
}

func speechFixture(duration: Double = 1, waveform: Bool = false) throws -> Data {
    let url = URL.temporaryDirectory.appendingPathComponent("speech-fixture-\(UUID()).wav")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
    let frames = AVAudioFrameCount(8_000 * duration)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
    buffer.frameLength = frames
    buffer.floatChannelData![0].initialize(repeating: 0, count: Int(frames))
    if waveform {
        for index in 0..<Int(frames) {
            let t = Double(index) / 8_000
            let envelope = pow(abs(sin(t * 2.1) * cos(t * 5.3)), 2)
            buffer.floatChannelData![0][index] = Float(sin(t * 880 * .pi) * envelope * 0.08)
        }
    }
    do {
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
    return try Data(contentsOf: url)
}

@MainActor
func waitForSpeech(_ session: SpeechSession, phase: SpeechSession.Phase) async throws {
    for _ in 0..<400 {
        if session.phase == phase { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    try #require(session.phase == phase)
}

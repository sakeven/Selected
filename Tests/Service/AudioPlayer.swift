import AVFoundation
import Testing
@testable import Selected

struct AudioPlayerTests {
    @Test @MainActor func loadingSeekingAndPausingPreservePlaybackState() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_000))
        buffer.frameLength = 8_000
        buffer.floatChannelData![0].initialize(repeating: 0, count: 8_000)
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }

        let player = AudioPlayer()
        player.loadAudio(url: url)
        #expect(abs(player.duration - 1) < 0.001)
        #expect(!player.isPlaying)
        #expect(player.currentTime == 0)
        player.seek(to: 0.4)
        #expect(player.currentTime == 0.4)
        player.pause()
        #expect(!player.isPlaying)
        #expect(player.currentTime == 0.4)
        #expect(abs(player.duration - 1) < 0.001)
    }
}

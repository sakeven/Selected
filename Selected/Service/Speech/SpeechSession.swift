import AVFoundation
import Observation

@MainActor @Observable
final class SpeechSession: NSObject {
    enum Phase {
        case idle, generating, playing, paused, finished, failed
    }

    private(set) var phase: Phase = .idle
    private(set) var text = ""
    private(set) var excerpt = ""
    private(set) var voice = ""
    private(set) var audioURL: URL?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?
    private(set) var savedURL: URL?
    var saveError: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var utterance: AVSpeechUtterance?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var generation: Task<Void, Never>?
    @ObservationIgnored private var generateAudio: (() async throws -> Data)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(text: String, voice: String, generateAudio: (() async throws -> Data)?) {
        stop()
        self.text = text
        excerpt = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        self.voice = voice
        self.generateAudio = generateAudio
        retry()
    }

    func retry() {
        generation?.cancel()
        player?.stop()
        player = nil
        timer?.invalidate()
        removeAudioFile()
        currentTime = 0
        duration = 0
        savedURL = nil
        saveError = nil
        errorMessage = nil
        guard let generateAudio else {
            speakWithSystemVoice()
            return
        }
        phase = .generating
        generation = Task { [weak self] in
            do {
                let data = try await generateAudio()
                try Task.checkCancellation()
                guard let self else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("selected-speech-\(UUID()).wav")
                audioURL = url
                try data.write(to: url)
                let player = try AVAudioPlayer(contentsOf: url)
                self.player = player
                player.delegate = self
                duration = player.duration
                play()
            } catch {
                guard !Task.isCancelled, let self else { return }
                removeAudioFile()
                switch (error as? URLError)?.code {
                case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    errorMessage = String(localized: "audio.networkError")
                case .timedOut:
                    errorMessage = String(localized: "audio.timeoutError")
                default:
                    errorMessage = error.localizedDescription
                }
                phase = .failed
            }
        }
    }

    func togglePlayback() {
        switch phase {
        case .playing:
            player?.pause()
            if utterance != nil { synthesizer.pauseSpeaking(at: .immediate) }
            timer?.invalidate()
            phase = .paused
        case .paused, .finished:
            play()
        case .failed:
            retry()
        case .idle, .generating:
            break
        }
    }

    private func play() {
        if let player {
            if phase == .finished || currentTime >= duration {
                player.currentTime = 0
                currentTime = 0
            }
            guard player.play() else {
                errorMessage = String(localized: "audio.playbackError")
                phase = .failed
                return
            }
            phase = .playing
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let player = self.player else { return }
                    self.currentTime = player.currentTime
                }
            }
        } else if phase == .paused {
            synthesizer.continueSpeaking()
            phase = .playing
        } else {
            speakWithSystemVoice()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        currentTime = min(max(time, 0), duration)
        player.currentTime = currentTime
        if phase == .finished { phase = .paused }
    }

    func stop() {
        generation?.cancel()
        generation = nil
        player?.stop()
        player = nil
        utterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        timer = nil
        removeAudioFile()
        currentTime = 0
        duration = 0
        errorMessage = nil
        savedURL = nil
        saveError = nil
        generateAudio = nil
        phase = .idle
    }

    func save(to directory: URL = URL.documentsDirectory.appendingPathComponent("Selected")) {
        guard let audioURL, savedURL == nil else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(audioURL.lastPathComponent)
            try FileManager.default.copyItem(at: audioURL, to: destination)
            savedURL = destination
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func speakWithSystemVoice() {
        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = 0.8
        utterance.postUtteranceDelay = 0.2
        utterance.volume = 0.8
        self.utterance = utterance
        phase = .playing
        synthesizer.speak(utterance)
    }

    private func removeAudioFile() {
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
    }

    isolated deinit {
        generation?.cancel()
        timer?.invalidate()
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
    }
}

extension SpeechSession: AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            timer?.invalidate()
            currentTime = duration
            errorMessage = flag ? nil : String(localized: "audio.playbackError")
            phase = flag ? .finished : .failed
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            timer?.invalidate()
            errorMessage = error?.localizedDescription ?? String(localized: "audio.playbackError")
            phase = .failed
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.utterance === utterance else { return }
            phase = .finished
        }
    }
}

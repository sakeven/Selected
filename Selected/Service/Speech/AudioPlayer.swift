import AppKit
import AVFoundation
import Combine

@MainActor
class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    private var timer: Timer?

    func loadAudio(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            duration = player?.duration ?? 0.0
        } catch {
            logger.error("Error loading audio file: \(error)")
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying = self.player?.isPlaying ?? false
                if self.isPlaying {
                    self.currentTime = self.player?.currentTime ?? 0.0
                } else {
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func save(_ audioURL: URL) {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsDirectory = paths.first else{
            return
        }
        let unixTime = Int(Date().timeIntervalSince1970)
        let tts = documentsDirectory.appending(path: "Selected/tts-\(unixTime).mp3")
        do{
            try FileManager.default.createDirectory(at: tts.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: audioURL, to: tts)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tts.deletingLastPathComponent().path)
        } catch {
            logger.error("move failed \(error)")
        }
    }
}

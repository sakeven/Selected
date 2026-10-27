import SwiftUI

struct ReadAloudButton: View {
    let text: String
    private var session: SpeechSession { TTSManager.session }
    private var isCurrent: Bool { session.text == text && session.phase != .idle }

    var body: some View {
        Button {
            Task { await TTSManager.speak(text) }
        } label: {
            Group {
                if isCurrent && session.phase == .generating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(.rect)
        }
        .buttonStyle(AppIconButtonStyle(isSelected: isCurrent))
        .accessibilityLabel(label)
        .help(label)
    }

    private var label: LocalizedStringKey {
        guard isCurrent else { return "chat.readAloud" }
        switch session.phase {
        case .generating: return "audio.cancel"
        case .playing: return "audio.pause"
        case .paused: return "audio.play"
        case .finished: return "audio.replay"
        case .failed: return "audio.retry"
        case .idle: return "chat.readAloud"
        }
    }

    private var symbol: String {
        guard isCurrent else { return "speaker.wave.2" }
        switch session.phase {
        case .playing: return "pause.fill"
        case .paused: return "play.fill"
        case .finished: return "arrow.counterclockwise"
        case .failed: return "arrow.clockwise"
        case .idle, .generating: return "speaker.wave.2"
        }
    }
}

import Defaults
import Foundation

@MainActor
public enum TTSManager {
    static let session = SpeechSession()
    private static let audioLoader = TTSAudioLoader()

    public static func speak(_ text: String) async {
        if session.text == text, session.phase != .idle {
            if session.phase == .generating {
                WindowManager.shared.closeSpeechWindow()
                return
            }
            session.togglePlayback()
        } else {
            let token = APIKeyStore.shared.value(for: .openAI)
            if token.isEmpty {
                session.start(text: text, voice: String(localized: "audio.systemVoice"), generateAudio: nil)
            } else {
                let speech = OpenAISpeech(host: Defaults[.openAIAPIHost],
                                          model: Defaults[.openAITTSModel],
                                          voice: Defaults[.openAIVoice],
                                          instructions: Defaults[.openAITTSInstructions])
                let cacheKey = [speech.host, speech.model, speech.voice.rawValue, speech.instructions, text].joined(separator: "\0")
                session.start(text: text, voice: speech.voice.rawValue.capitalized) {
                    try await audioLoader.data(for: cacheKey) {
                        try await speech.audio(for: text, token: token)
                    }
                }
            }
        }
        WindowManager.shared.showSpeechWindow(session: session)
    }
}

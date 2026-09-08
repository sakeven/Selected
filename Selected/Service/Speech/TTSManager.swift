//
//  TTSManager.swift
//  Selected
//
//  Created by sake on 20/3/25.
//


import Foundation
import AVFoundation
import Defaults
import SwiftUI
import OpenAI

@MainActor
public enum TTSManager {

    // MARK: - 属性

    /// 系统语音合成器，用于当 OpenAI APIKey 为空时调用系统 TTS
    private static let speechSynthesizer = AVSpeechSynthesizer()

    /// OpenAI 语音合成播放使用的音频播放器
    private static var audioPlayer: AVAudioPlayer?

    private static let audioLoader = TTSAudioLoader()

    // MARK: - 系统 TTS

    /// 使用系统语音合成（AVSpeechSynthesizer）朗读文本
    private static func systemSpeak(_ text: String) {
        speechSynthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = 0.8
        utterance.postUtteranceDelay = 0.2
        utterance.volume = 0.8
        speechSynthesizer.speak(utterance)
    }

    // MARK: - OpenAI TTS 调用

    /// 通过 OpenAI API 调用语音合成，并直接播放生成的语音
    private static func play(text: String) async {
        guard let data = await fetchTTSData(text: text) else { return }
        audioPlayer?.stop()
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            logger.error("Audio player error: \(error)")
        }
    }

    /// 通过 OpenAI API 获取 TTS 音频数据，适用于需要自定义播放方式（例如在新窗口中播放）的场景
    private static func fetchTTSData(text: String) async -> Data? {
        do {
            return try await audioLoader.data(for: text) {
                let configuration = OpenAI.Configuration(token: APIKeyStore.shared.value(for: .openAI),
                                                         host: Defaults[.openAIAPIHost],
                                                         timeoutInterval: 60.0)
                let openAI = OpenAI(configuration: configuration)
                let model = Defaults[.openAITTSModel]
                let instructions = model == .gpt_4o_mini_tts ? Defaults[.openAITTSInstructions] : ""
                let query = AudioSpeechQuery(model: model,
                                             input: text,
                                             voice: Defaults[.openAIVoice],
                                             instructions: instructions,
                                             responseFormat: .mp3,
                                             speed: 1.0)
                let result = try await openAI.audioCreateSpeech(query: query)
                return result.audio
            }
        } catch {
            logger.error("audioCreateSpeech error: \(error)")
            return nil
        }
    }

    // MARK: - 综合调用入口

    /// 综合 TTS 播放函数，根据 OpenAI APIKey 和文本内容决定调用系统 TTS 还是 OpenAI TTS
    ///
    /// - Parameters:
    ///   - text: 待朗读文本
    ///   - view: 是否以视图窗口方式播放（适用于多句文本）；默认为 true
    ///
    /// 如果 OpenAI APIKey 为空，则调用系统 TTS，否则：
    /// - 当文本为单词或 view 为 false 时直接播放语音；
    /// - 否则，获取 TTS 数据后在新窗口中播放（需 WindowManager 实现相关方法）。
    public static func speak(_ text: String, view: Bool = true) async {
        // 如果未配置 OpenAI APIKey，则调用系统语音
        if APIKeyStore.shared.value(for: .openAI).isEmpty {
            systemSpeak(text)
        } else {
            if isWord(str: text) || !view {
                await play(text: text)
            } else {
                if let data = await fetchTTSData(text: text) {
                    WindowManager.shared.createAudioPlayerWindow(data)
                }
            }
        }
    }

    /// 停止所有正在进行的语音合成播放，包括系统 TTS 与 OpenAI TTS
    public static func stopSpeak() {
        speechSynthesizer.stopSpeaking(at: .word)
        audioPlayer?.stop()
    }
}

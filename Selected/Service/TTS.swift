//
//  TTS.swift
//  Selected
//
//  Created by sake on 2024/3/28.
//

import Foundation
import AVFoundation
import Defaults
import SwiftUI

let speechSynthesizer = AVSpeechSynthesizer()

func systemSpeak(_ text: String) {
    speechSynthesizer.stopSpeaking(at: .word)
    let utterance = AVSpeechUtterance(string: text)
    utterance.pitchMultiplier = 0.8
    utterance.postUtteranceDelay = 0.2
    utterance.volume = 0.8
    speechSynthesizer.speak(utterance)
}

func speak(_ text: String) async {
    if Defaults[.openAIAPIKey].isEmpty {
        systemSpeak(text)
    } else {
        if isWord(str: text) {
            await openAITTS(text)
        } else {
            DispatchQueue.main.async {
                WindowManager.shared.createTTSWindow(withText: text)
            }
        }
    }
}

func stopSpeak() {
    speechSynthesizer.stopSpeaking(at: .word)
    audioPlayer?.stop()
}

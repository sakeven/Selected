//
//  Defaults.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import Defaults
import Foundation
import OpenAI
import ShortcutRecorder
import SwiftUI



// Service Configuration
extension Defaults.Keys {
    
    static let search = Key<String>("SearchURL", default: "https://www.google.com/search?q={selected.text}")
    

    static let useTextFieldInChat = Key<Bool>("UseTextFieldInChat", default: false)

    static let aiService = Key<String>("AIService", default: "OpenAI")
    
    // OpenAI
    static let openAIAPIKey = Key<String>("OpenAIAPIKey", default: "")
    static let openAIAPIHost = Key<String>("OpenAIAPIHost",default: "api.openai.com")
    static let openAIModel = Key<OpenAIModel>("OpenAIModel", default: .gpt3_5Turbo)
    static let openAIVoice = Key<AudioSpeechQuery.AudioSpeechVoice>("OpenAIVoice", default: .shimmer)

    
    // Gemini
    static let geminiAPIKey = Key<String>("GeminiAPIKey", default: "")

    // Claude
    static let claudeAPIKey = Key<String>("ClaudeAPIKey", default: "")
    static let claudeAPIHost = Key<String>("ClaudeAPIHost", default: "https://api.anthropic.com")
    static let claudeModel = Key<String>("ClaudeModel", default: ClaudeModel.claude35Sonnet.value)

    // clipboard
    static let enableClipboard = Key<Bool>("EnableClipboard", default: false)
    static let clipboardShortcut = Key<Shortcut>("ClipboardShortcut", default: Shortcut(keyEquivalent: "⌥Space")!)
    static let clipboardHistoryTime = Key<ClipboardHistoryTime>("ClipboardHistoryTime", default: ClipboardHistoryTime.SevenDays)
}

enum ClipboardHistoryTime: String, Defaults.Serializable, CaseIterable {
    case OneDay = "24 Hours", SevenDays="7 Days", ThirtyDays = "30 Days"
    case ThreeMonths = "3 Months", SixMonths="6 Months", OneYear = "1 Year"
    
    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
}


extension AudioSpeechQuery.AudioSpeechVoice: Defaults.Serializable{}


extension Shortcut: Defaults.Serializable{
    public static let bridge = ShortcutBridge()
}

public struct ShortcutBridge: Defaults.Bridge {
    public typealias Value = Shortcut
    public typealias Serializable = [ShortcutKey: Any]
    
    public func serialize(_ value: Value?) -> Serializable? {
        guard let value else {
            return nil
        }
        return value.dictionaryRepresentation
    }
    
    public func deserialize(_ object: Serializable?) -> Value? {
        guard
            let val = object
        else {
            return nil
        }
        return Shortcut(dictionary: val)
    }
}


// 应用程序支持目录的URL
let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Selected/", isDirectory: true)


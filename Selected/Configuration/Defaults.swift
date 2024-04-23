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
    
    
    static let aiService = Key<String>("AIService", default: "OpenAI")
    
    // OpenAI
    static let openAIAPIKey = Key<String>("OpenAIAPIKey", default: "")
    static let openAIAPIHost = Key<String>("OpenAIAPIHost",default: "api.openai.com")
    static let openAIModel = Key<Model>("OpenAIModel", default: "gpt-3.5-turbo")
    
    // Gemini
    static let geminiAPIKey = Key<String>("GeminiAPIKey", default: "")
    static let geminiAPIHost = Key<String>("GeminiAPIHost", default: "")
    
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


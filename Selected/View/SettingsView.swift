//
//  SettingsView.swift
//  Selected
//
//  Created by sake on 2024/3/9.
//

import Foundation
import SwiftUI
import Defaults
import ServiceManagement
import OpenAI


struct SettingsView: View {
    @Default(.openAIAPIKey) var openAIAPIKey
    @Default(.openAIAPIHost) var openAIAPIHost
    
    @Default(.geminiAPIKey) var geminiAPIKey
    @Default(.geminiAPIHost) var geminiAPIHost
    
    @Default(.aiService) var aiService
    let pickerValues = ["OpenAI", "Gemini"]
    
    @Default(.openAIModel) var openAIModel
    
    @Default(.search) var searchURL
    
    @Default(.openAIVoice) var openAIVoice
    
    @State var launchAtLogin: Bool
    
    init() {
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    var body: some View {
        TabView{
            HStack {
                Form{
                    Section(header: Text("General")) {
                        Toggle(isOn: $launchAtLogin, label: {
                            Text("Launch at login")
                        }).onChange(of: launchAtLogin) {  newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                NSLog(error.localizedDescription)
                            }
                        }
                        
                        TextField("Search URL", text: $searchURL)
                    }
                    
                    Section(header: Text("AIService")) {
                        Picker("AIService", selection: $aiService, content: {
                            ForEach(pickerValues, id: \.self) {
                                Text($0)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                    }
                    Section(header: Text("OpenAI")) {
                        SecureField("APIKey", text: $openAIAPIKey)
                        TextField("APIHost", text: $openAIAPIHost)
                        Picker("Model", selection: $openAIModel, content: {
                            ForEach(OpenAIModels, id: \.self) {
                                Text($0)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                        
                        Picker("Voice", selection: $openAIVoice, content: {
                            ForEach(AudioSpeechQuery.AudioSpeechVoice.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section(header: Text("Gemini")) {
                        SecureField("APIKey", text: $geminiAPIKey)
                        TextField("APIHost", text: $geminiAPIHost)
                    }
                }.formStyle(.grouped) // 成组
                    .frame(width: 400).padding()
            }.tabItem {
                Label {
                    Text("General")
                } icon: {
                    Image(systemName: "gear")
                }
            }
            PluginListView().tabItem {
                Label {
                    Text("Extensions")
                } icon: {
                    Image(systemName: "puzzlepiece")
                }
            }
            ActionListView().tabItem {
                Label {
                    Text("Actions")
                } icon: {
                    Image(systemName: "a.square.fill")
                }
            }
            ApplicationActionListView().tabItem {
                Label {
                    Text("Applications")
                } icon: {
                    Image(systemName: "apple.terminal")
                }
            }
            ShortcutView().tabItem() {
                Label {
                    Text("Clipboard")
                } icon: {
                    Image(systemName: "doc.on.clipboard.fill")
                }
            }
        }
    }
}

import ShortcutRecorder

struct ShortcutView: View {
    @Default(.clipboardShortcut) var shortcut
    @Default(.enableClipboard) var enableClipboard
    @Default(.clipboardHistoryTime) var keepTime: ClipboardHistoryTime

    var body: some View {
        VStack {
            Form{
                Section(header: Text("General")) {
                    Toggle(isOn: $enableClipboard, label: {
                        Text("Clipboard History")
                    })
                    HStack{
                        Text("HotKey")
                        ShortcutRecorderView(shortcut: $shortcut)
                            .frame(height: 25)
                    }
                    Picker("Keep History For", selection: $keepTime, content: {
                        ForEach(ClipboardHistoryTime.allCases, id: \.self) {
                            Text($0.localizedName)
                        }
                    }).pickerStyle(DefaultPickerStyle()).onChange(of: keepTime) { _ in
                        PersistenceController.shared.cleanTask()
                    }
                }
            }.formStyle(.grouped) // 成组
                .frame(width: 400).padding()
        }
    }
}

#Preview {
    SettingsView()
}

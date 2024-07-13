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

    @Environment(\.colorScheme) var colorScheme


    @Default(.openAIAPIKey) var openAIAPIKey
    @Default(.openAIAPIHost) var openAIAPIHost

    @Default(.geminiAPIKey) var geminiAPIKey
    @Default(.geminiAPIHost) var geminiAPIHost


    @Default(.claudeAPIKey) var claudeAPIKey
    @Default(.claudeAPIHost) var claudeAPIHost

    @Default(.aiService) var aiService
    let pickerValues = ["OpenAI", "Gemini", "Claude"]

    @Default(.openAIModel) var openAIModel
    @State var selectedOpenAIModel: String
    @State var customOpenAIMode: String

    @Default(.search) var searchURL

    @Default(.openAIVoice) var openAIVoice

    @State var launchAtLogin: Bool

    init() {
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        if OpenAIModels.contains(Defaults[.openAIModel]) {
            selectedOpenAIModel = Defaults[.openAIModel]
            customOpenAIMode = ""
        } else {
            selectedOpenAIModel = "Custom"
            customOpenAIMode = Defaults[.openAIModel]
        }
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

                        Picker("Model", selection: $selectedOpenAIModel, content: {
                            ForEach(OpenAIModels, id: \.self) {
                                Text($0)
                            }
                            Text("Custom").tag("Custom")
                        }).pickerStyle(DefaultPickerStyle())
                            .onChange(of: selectedOpenAIModel) { newValue in
                                if newValue == "Custom" {
                                    customOpenAIMode = ""
                                    Defaults[.openAIModel] = ""
                                } else {
                                    Defaults[.openAIModel] = newValue
                                    customOpenAIMode = ""
                                }
                            }

                        if selectedOpenAIModel == "Custom" {
                            TextField("Custom model", text: $customOpenAIMode)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .onChange(of: customOpenAIMode){ newValue in
                                    if OpenAIModels.contains(customOpenAIMode) {
                                        selectedOpenAIModel = customOpenAIMode
                                    }
                                    Defaults[.openAIModel] = customOpenAIMode
                                }
                        }

                        Picker("Voice", selection: $openAIVoice, content: {
                            ForEach(AudioSpeechQuery.AudioSpeechVoice.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                    }

                    Section(header: Text("Claude")) {
                        SecureField("APIKey", text: $claudeAPIKey)
                        TextField("APIHost", text: $claudeAPIHost)
                    }

                    Section(header: Text("Gemini")) {
                        SecureField("APIKey", text: $geminiAPIKey)
                        TextField("APIHost", text: $geminiAPIHost)
                    }
                }
                .scrollContentBackground(.hidden)
                .formStyle(.grouped) // 成组
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
        .background(colorScheme == .dark ?Color(NSColor.windowBackgroundColor): Color.white)
    }
}

import ShortcutRecorder

struct ShortcutView: View {
    @Default(.clipboardShortcut) var shortcut
    @Default(.enableClipboard) var enableClipboard
    @Default(.clipboardHistoryTime) var keepTime: ClipboardHistoryTime

    @Environment(\.colorScheme) var colorScheme

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
            }
            .scrollContentBackground(.hidden)
            .formStyle(.grouped) // 成组
            .frame(width: 400).padding()
        }
    }
}

#Preview {
    SettingsView()
}

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
import ShortcutRecorder


struct SettingsView: View {

    @Environment(\.colorScheme) var colorScheme

    @Default(.aiService) var aiService
    let aiServicePickerValues = ["OpenAI", "Claude"]


    @Default(.openAIAPIKey) var openAIAPIKey
    @Default(.openAIAPIHost) var openAIAPIHost
    @Default(.openAIModel) var openAIModel
    @State var selectedOpenAIModel: String
    @State var customOpenAIMode: String
    @Default(.openAIModelReasoningEffort) var openAIModelReasoningEffort
    @Default(.openAIVoice) var openAIVoice
    @Default(.openAITTSModel) var openAITTSModel
    @Default(.openAITTSInstructions) var openAITTSInstructions
    @Default(.openAITranslationModel) var openAITranslationModel


    @Default(.geminiAPIKey) var geminiAPIKey


    @Default(.claudeAPIKey) var claudeAPIKey
    @Default(.claudeAPIHost) var claudeAPIHost
    @Default(.claudeModel) var claudeModel

    @Default(.search) var searchURL

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

                        SpotlightShortcutView()
                    }

                    Section(header: Text("AIService")) {
                        Picker("AIService", selection: $aiService, content: {
                            ForEach(aiServicePickerValues, id: \.self) {
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

                        if openAIModel == .o3_mini || openAIModel == .o1 || openAIModel == .o1_mini {
                            Picker("ReasoningEffort", selection: $openAIModelReasoningEffort, content: {
                                ForEach(ChatQuery.ReasoningEffort.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }).pickerStyle(DefaultPickerStyle())
                        }

                        Picker("Translation", selection: $openAITranslationModel, content: {
                            ForEach(OpenAITranslationModels, id: \.self) {
                                Text($0)
                            }
                        }).pickerStyle(DefaultPickerStyle())

                        Picker("Voice", selection: $openAIVoice, content: {
                            ForEach(AudioSpeechQuery.AudioSpeechVoice.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }).pickerStyle(DefaultPickerStyle())

                        Picker("TTSModel", selection: $openAITTSModel, content: {
                            ForEach(OpenAITTSModels, id: \.self) {
                                Text($0)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                        if openAITTSModel == .gpt_4o_mini_tts {
                            TextField("TTSInstructions", text: $openAITTSInstructions)
                        }
                    }

                    Section(header: Text("Claude")) {
                        SecureField("APIKey", text: $claudeAPIKey)
                        TextField("APIHost", text: $claudeAPIHost)
                        Picker("Model", selection: $claudeModel, content: {
                            ForEach(ClaudeModel.allCases, id: \.value) {
                                Text($0.value)
                            }
                        }).pickerStyle(DefaultPickerStyle())
                    }

                    Section(header: Text("Gemini")) {
                        SecureField("APIKey", text: $geminiAPIKey)
                    }
                }
                .scrollContentBackground(.hidden)
                .formStyle(.grouped) // 成组
                .frame(width: 400)

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


struct SpotlightShortcutView: View {
    // 很奇怪把这行直接放在 SettingsView 里会，导致 Spotlight 里无法使用中文输入法
    // 需要放在一个单独里的 View 里
    @Default(.spotlightShortcut) var spotlightShortcut

    var body: some View {
        HStack{
            Text("Spotlight HotKey")
            ShortcutRecorderView(shortcut: $spotlightShortcut)
                .frame(height: 25)
        }
        EmptyView()
    }
}

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
            .frame(width: 400)
        }
    }
}

#Preview {
    SettingsView()
}

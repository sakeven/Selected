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


struct SettingsView: View {
    @Default(.openAIAPIKey) var openAIAPIKey
    @Default(.openAIAPIHost) var openAIAPIHost
    
    @Default(.geminiAPIKey) var geminiAPIKey
    @Default(.geminiAPIHost) var geminiAPIHost
    
    @Default(.aiService) var aiService
    let pickerValues = ["OpenAI", "Gemini"]
    
    @Default(.search) var searchURL
    
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
                            Text("LaunchAtLogin")
                        }).onChange(of: launchAtLogin) { oldValue, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                Swift.print(error.localizedDescription)
                            }
                            if newValue != (SMAppService.mainApp.status == .enabled) {
                                launchAtLogin = oldValue
                            }
                        }
                        TextField("SearchURL", text: $searchURL)
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
        }
    }
}


#Preview {
    SettingsView()
}

//
//  SettingsView.swift
//  Selected
//
//  Created by sake on 2024/3/9.
//

import Foundation
import SwiftUI
import Defaults


struct SettingsView: View {
    @Default(.openAIAPIKey) var openAIAPIKey
    @Default(.openAIAPIHost) var openAIAPIHost
    
    @Default(.geminiAPIKey) var geminiAPIKey
    @Default(.geminiAPIHost) var geminiAPIHost
    
    @Default(.aiService) var aiService
    let pickerValues = ["OpenAI", "Gemini"]

    var body: some View {
        Spacer()
        HStack {
            Form{
                Picker("AIService", selection: $aiService, content: {
                    ForEach(pickerValues, id: \.self) {
                        Text($0)
                    }
                }).pickerStyle(DefaultPickerStyle())
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
        }
    }
}


#Preview {
    SettingsView()
}

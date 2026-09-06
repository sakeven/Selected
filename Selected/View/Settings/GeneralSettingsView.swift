import SwiftUI
import Defaults
import ServiceManagement
import OpenAI

struct GeneralSettingsView: View {
    @Default(.aiService) private var aiService
    @Default(.openAIAPIKey) private var openAIAPIKey
    @Default(.openAIAPIHost) private var openAIAPIHost
    @Default(.openAIModel) private var openAIModel
    @Default(.openAIModelReasoningEffort) private var openAIModelReasoningEffort
    @Default(.openAIVoice) private var openAIVoice
    @Default(.openAITTSModel) private var openAITTSModel
    @Default(.openAITTSInstructions) private var openAITTSInstructions
    @Default(.openAITranslationModel) private var openAITranslationModel
    @Default(.claudeAPIKey) private var claudeAPIKey
    @Default(.claudeAPIHost) private var claudeAPIHost
    @Default(.claudeModel) private var claudeModel
    @Default(.search) private var searchURL
    @State private var launchAtLogin: Bool
    @State private var selectedOpenAIModel: String
    @State private var customOpenAIModel: String

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if OpenAIModels.contains(Defaults[.openAIModel]) {
            selectedOpenAIModel = Defaults[.openAIModel]
            customOpenAIModel = ""
        } else {
            selectedOpenAIModel = "Custom"
            customOpenAIModel = Defaults[.openAIModel]
        }
    }

    var body: some View {
        SettingsPage(title: "General", subtitle: "管理启动、搜索与 AI 服务，让 Selected 按你的习惯工作。") {
            SettingsSection(title: "基础设置") {
                HStack {
                    Text("Launch at login").font(.subheadline)
                    Spacer()
                    Toggle("Launch at login", isOn: $launchAtLogin).labelsHidden()
                }
                .onChange(of: launchAtLogin) {
                    do {
                        if launchAtLogin { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch { NSLog(error.localizedDescription) }
                }
                Divider().opacity(0.5)
                SettingsField(title: String(localized: "Search URL")) {
                    TextField("Search URL", text: $searchURL)
                }
                Divider().opacity(0.5)
                SpotlightShortcutView()
            }
            SettingsSection(title: "AIService") {
                SettingsMenuPicker(title: String(localized: "AIService"), values: ["OpenAI", "Claude"], selection: $aiService, label: { $0 })
            }
            openAISettings
            SettingsSection(title: "Claude") {
                SettingsField(title: String(localized: "APIKey")) {
                    SecureField("APIKey", text: $claudeAPIKey)
                }
                SettingsField(title: String(localized: "APIHost")) {
                    TextField("APIHost", text: $claudeAPIHost)
                }
                Divider().opacity(0.5)
                SettingsMenuPicker(title: String(localized: "Model"), values: ClaudeModel.allCases, selection: $claudeModel, label: { $0 })
            }
        }
    }

    private var openAISettings: some View {
        SettingsSection(title: "OpenAI") {
            SettingsField(title: String(localized: "APIKey")) {
                SecureField("APIKey", text: $openAIAPIKey)
            }
            SettingsField(title: String(localized: "APIHost")) {
                TextField("APIHost", text: $openAIAPIHost)
            }
            Divider().opacity(0.5)
            SettingsMenuPicker(title: String(localized: "Model"), values: OpenAIModels + ["Custom"], selection: $selectedOpenAIModel) {
                $0 == "Custom" ? String(localized: "Custom") : $0
            }
            .onChange(of: selectedOpenAIModel) {
                if selectedOpenAIModel == "Custom" {
                    customOpenAIModel = ""
                    openAIModel = ""
                } else {
                    openAIModel = selectedOpenAIModel
                    customOpenAIModel = ""
                    updateReasoningEffort(for: selectedOpenAIModel)
                }
            }
            if selectedOpenAIModel == "Custom" {
                SettingsField(title: String(localized: "Custom model")) {
                    TextField("Custom model", text: $customOpenAIModel)
                }
                .onChange(of: customOpenAIModel) {
                    if OpenAIModels.contains(customOpenAIModel) {
                        selectedOpenAIModel = customOpenAIModel
                    }
                    openAIModel = customOpenAIModel
                    updateReasoningEffort(for: customOpenAIModel)
                }
            }
            if isReasoningModel(openAIModel) {
                SettingsMenuPicker(title: String(localized: "ReasoningEffort"), values: openAIModel.supportedReasoningEfforts, selection: $openAIModelReasoningEffort, label: { $0.rawValue })
            }
            SettingsMenuPicker(title: String(localized: "Translation"), values: OpenAITranslationModels, selection: $openAITranslationModel, label: { $0 })
            Divider().opacity(0.5)
            SettingsMenuPicker(title: String(localized: "Voice"), values: AudioSpeechQuery.AudioSpeechVoice.allCases, selection: $openAIVoice, label: { $0.rawValue })
            SettingsMenuPicker(title: String(localized: "TTSModel"), values: OpenAITTSModels, selection: $openAITTSModel, label: { $0 })
            if openAITTSModel == .gpt_4o_mini_tts {
                SettingsField(title: String(localized: "TTSInstructions")) {
                    TextField("TTSInstructions", text: $openAITTSInstructions, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
        }
    }

    private func updateReasoningEffort(for model: String) {
        let supported = model.supportedReasoningEfforts
        guard !supported.isEmpty else { return }
        if !supported.contains(openAIModelReasoningEffort) {
            openAIModelReasoningEffort = supported[0]
        }
    }
}

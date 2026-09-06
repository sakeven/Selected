import SwiftUI

struct PluginTrialView: View {
    @Environment(\.dismiss) private var dismiss
    let plugin: Plugin
    let directory: URL
    private let values: [String: String]
    @State private var trial = PluginTrial()
    @State private var text = ""
    @State private var clipboardText = ""
    @State private var bundleID = ""
    @State private var webPageURL = ""
    @State private var editable = true
    @State private var actionID: String
    @State private var chooseApp = false
    @State private var applications: [Application] = []

    init(plugin: Plugin, directory: URL, actionID: String? = nil) {
        self.plugin = plugin
        self.directory = directory
        values = plugin.info.getOptionsValue()
        _actionID = State(initialValue: actionID ?? plugin.actions.first?.meta.identifier ?? "")
    }

    private var action: Action? { plugin.actions.first { $0.meta.identifier == actionID } }
    private var context: SelectedTextContext {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let urls = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url).filter { ["http", "https"].contains($0.scheme ?? "") }.map(\.absoluteString) ?? []
        return SelectedTextContext(Text: text, BundleID: bundleID, WebPageURL: webPageURL, URLs: urls, Editable: editable, ClipboardText: action?.meta.includeClipboard == true ? clipboardText : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(title: "Test Plugin", subtitle: "Preview the input, check matching rules, and inspect the result.").padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsCard {
                        SettingsMenuPicker(title: String(localized: "Action"), values: plugin.actions.map(\.meta.identifier), selection: $actionID) { id in
                            plugin.actions.first { $0.meta.identifier == id }?.meta.title ?? id
                        }
                        SettingsField(title: String(localized: "Sample Text")) {
                            TextEditor(text: $text).frame(height: 100).scrollContentBackground(.hidden)
                                .accessibilityLabel("Sample Text")
                        }
                        if action?.meta.includeClipboard == true {
                            SettingsField(title: String(localized: "Sample Clipboard Text")) {
                                TextEditor(text: $clipboardText).frame(height: 80).scrollContentBackground(.hidden)
                                    .accessibilityLabel("Sample Clipboard Text")
                            }
                            Text("Enter a sample here. Testing does not read your system clipboard.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        DisclosureGroup("Application Context") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    SettingsField(title: String(localized: "App Bundle Identifier")) {
                                        TextField("com.apple.Safari", text: $bundleID).accessibilityLabel("App Bundle Identifier")
                                    }
                                    Button("Choose App…", systemImage: "app") {
                                        applications = Application.available()
                                        chooseApp = true
                                    }.buttonStyle(SettingsButtonStyle())
                                        .popover(isPresented: $chooseApp) {
                                            ApplicationPickerView(applications: applications) { app in bundleID = app.id; chooseApp = false }
                                        }
                                }
                                SettingsField(title: String(localized: "Webpage URL")) {
                                    TextField("https://example.com", text: $webPageURL).accessibilityLabel("Webpage URL")
                                }
                                Toggle("Text can be pasted", isOn: $editable).toggleStyle(.switch).controlSize(.small)
                            }.padding(.top, 12)
                        }
                    }.disabled(trial.isRunning)
                    if let action {
                        preview(action)
                        if action.gpt != nil || action.runCommand != nil {
                            Text(action.gpt != nil ? "The sample is sent to your configured AI provider. Results stay here instead of being pasted or copied." : "The command runs locally. Results stay here instead of being pasted or copied.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let tools = action.gpt?.tools, !tools.isEmpty {
                                Label("This action may call its configured AI tools during the test.", systemImage: "wrench.and.screwdriver")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("URL, shortcut, and service actions are previewed here without opening apps or sending keystrokes.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !trial.status.isEmpty {
                        SettingsCard {
                            HStack {
                                Label(trial.status, systemImage: trial.failed ? "exclamationmark.circle" : "info.circle")
                                    .foregroundStyle(trial.failed ? Color.red : .blue)
                                Spacer()
                                if let duration = trial.duration { Text("\(duration, specifier: "%.2f") s").font(.caption).foregroundStyle(.secondary) }
                            }
                            if !trial.output.isEmpty { Text(trial.output).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            if !trial.diagnostics.isEmpty {
                                Divider()
                                Text(trial.diagnostics).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            }
                        }
                    }
                }.padding(24)
            }
            Divider()
            HStack {
                if let action, action.gpt != nil || action.runCommand != nil {
                    Button(action.gpt != nil ? String(localized: "Run AI") : String(localized: "Run Command"), systemImage: "play.fill") {
                        trial.run(action, plugin: plugin, context: context, directory: directory)
                    }.buttonStyle(SettingsButtonStyle(emphasis: .primary)).disabled(trial.isRunning)
                    if trial.isRunning {
                        ProgressView().controlSize(.small)
                        Button("Cancel Run", action: trial.cancel).buttonStyle(SettingsButtonStyle())
                    }
                }
                Spacer()
                Button("Done") { trial.cancel(); dismiss() }.buttonStyle(SettingsButtonStyle()).keyboardShortcut(.cancelAction)
            }.padding(16)
        }
        .frame(width: 720, height: 740)
        .background(Color("SettingsBackground")).tint(.blue)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
        .onDisappear { trial.cancel() }
    }

    @ViewBuilder private func preview(_ action: Action) -> some View {
        let result = Result { try PluginTrial.preview(action, plugin: plugin, context: context, values: values) }
        SettingsCard {
            switch result {
            case .success(let preview):
                Label("Input matches · Preview", systemImage: "checkmark.circle").foregroundStyle(.blue)
                Text(preview.isEmpty ? String(localized: "Empty input") : preview)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failure(let error):
                Label(PluginRedactor(info: plugin.info, values: values).redact(error.localizedDescription), systemImage: "exclamationmark.circle").foregroundStyle(.orange)
            }
        }
    }
}

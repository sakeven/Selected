import SwiftUI

struct PluginActionEditorView: View {
    @Binding var action: Action

    var body: some View {
        SettingsField(title: String(localized: "Action Name")) {
            TextField("For example: Summarize", text: $action.meta.title).accessibilityLabel("Action Name")
        }
        PluginSegmentedControl(values: ActionKind.allCases, selection: Binding(get: { action.kind }, set: { action.setKind($0) }), title: { $0.title })
        switch action.kind {
        case .url:
            SettingsField(title: String(localized: "URL Template")) {
                TextField("https://example.com/search?q={selected.text}", text: Binding(get: { action.url?.url ?? "" }, set: { action.url?.url = $0 }), axis: .vertical)
                    .accessibilityLabel("URL Template")
            }
            Text("Use {selected.text} for selected text and {selected.options.identifier} for an option value.")
                .font(.caption).foregroundStyle(.secondary)
        case .service:
            SettingsField(title: String(localized: "macOS Service Name")) {
                TextField("Make Sticky", text: Binding(get: { action.service?.name ?? "" }, set: { action.service?.name = $0 }))
                    .accessibilityLabel("macOS Service Name")
            }
        case .keycombo:
            SettingsField(title: String(localized: "Keyboard Shortcuts · One per line")) {
                TextEditor(text: Binding(get: {
                    action.keycombo?.keycombos?.joined(separator: "\n") ?? action.keycombo?.keycombo ?? ""
                }, set: { value in
                    let combos = value.components(separatedBy: "\n")
                    if combos.count == 1 {
                        action.keycombo?.keycombo = value
                        action.keycombo?.keycombos = nil
                    } else {
                        action.keycombo?.keycombo = ""
                        action.keycombo?.keycombos = combos
                    }
                }))
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(minHeight: 65).accessibilityLabel("Keyboard Shortcuts")
            }
            Text("For example, cmd shift c. Multiple shortcuts run in order.")
                .font(.caption).foregroundStyle(.secondary)
            if action.keycombo?.supported != nil {
                Text("Existing app matching rules are preserved. Edit them in YAML.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .gpt:
            SettingsField(title: String(localized: "Prompt")) {
                TextEditor(text: Binding(get: { action.gpt?.prompt ?? "" }, set: { action.gpt?.prompt = $0 }))
                    .font(.body).scrollContentBackground(.hidden)
                    .frame(minHeight: 120).accessibilityLabel("AI Prompt")
            }
            Text("Use {{selected.text}} to insert selected text and {{options.identifier}} to insert an option value.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Enable reasoning", isOn: Binding(get: { action.gpt?.reasoning ?? (action.meta.after == nil || action.meta.after == AfterAction.none) }, set: { action.gpt?.reasoning = $0 }))
                .toggleStyle(.switch).controlSize(.small)
            if let tools = action.gpt?.tools, !tools.isEmpty {
                Label("\(tools.count) AI tools preserved. Edit them in YAML.", systemImage: "wrench.and.screwdriver")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .runCommand:
            SettingsField(title: String(localized: "Command and Arguments")) {
                TextEditor(text: Binding(get: { action.runCommand?.command.joined(separator: "\n") ?? "" }, set: {
                    action.runCommand?.command = $0.isEmpty ? [] : $0.components(separatedBy: "\n")
                }))
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(minHeight: 120).accessibilityLabel("Command and Arguments")
            }
            Text("Enter the program on the first line, then one argument per line. Selected text is passed through SELECTED_TEXT. The working directory is the plugin package.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if action.gpt != nil || action.runCommand != nil || action.url != nil {
            Toggle("Include clipboard text", isOn: Binding(get: { action.meta.includeClipboard == true }, set: { action.meta.includeClipboard = $0 ? true : nil }))
                .toggleStyle(.switch).controlSize(.small)
            if action.meta.includeClipboard == true {
                Text("Capture clipboard text when this action runs. Retries reuse the captured text.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(action.gpt != nil ? "AI template: {{selected.clipboardText}}" : action.url != nil ? "URL template: {selected.clipboardText}" : "Command variable: SELECTED_CLIPBOARD_TEXT")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        if action.gpt != nil || action.runCommand != nil {
            SettingsMenuPicker(title: String(localized: "Output Handling"), values: AfterAction.allCases,
                             selection: Binding<AfterAction>(get: { action.meta.after ?? AfterAction.none }, set: { action.meta.after = $0 }), label: resultTitle)
        }
        DisclosureGroup("Display Conditions") {
            VStack(alignment: .leading, spacing: 16) {
                if action.popclip != nil {
                    Label("PopClip input matching is preserved. Edit its rules in YAML; changing the action type uses Selected's native behavior.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(ActionRequirement.allCases, id: \.self) { requirement in
                    Toggle(requirement.title, isOn: Binding(get: {
                        action.meta.requirements?.contains(requirement) == true
                    }, set: { enabled in
                        var requirements = action.meta.requirements ?? []
                        requirements.removeAll { $0 == requirement }
                        if enabled { requirements.append(requirement) }
                        action.meta.requirements = requirements.isEmpty ? nil : requirements
                    })).toggleStyle(.switch).controlSize(.small)
                }
                SettingsField(title: String(localized: "Text Regular Expression · Optional")) {
                    TextField("No limit", text: $action.meta.regex.text).accessibilityLabel("Text Regular Expression")
                }
                PluginStringListField(title: String(localized: "Show Only in These Apps · Comma-separated bundle IDs"), values: $action.meta.requiredApps)
                PluginStringListField(title: String(localized: "Hide in These Apps · Comma-separated bundle IDs"), values: $action.meta.excludedApps)
                Text("All conditions must match. The action receives the full selected text.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 14)
        }.font(.subheadline)
        DisclosureGroup("More Settings") {
            VStack(alignment: .leading, spacing: 16) {
                SettingsField(title: String(localized: "Action Identifier")) {
                    TextField("com.example.action", text: $action.meta.identifier).accessibilityLabel("Action Identifier")
                }
                Text("App configurations reference this identifier. Keep it unchanged after publishing.")
                    .font(.caption).foregroundStyle(.secondary)
                SettingsField(title: String(localized: "Icon")) {
                    TextField("symbol:bolt", text: $action.meta.icon).accessibilityLabel("Action Icon")
                }
                SettingsField(title: String(localized: "Description")) {
                    TextField("Briefly describe this action", text: $action.meta.description.text).accessibilityLabel("Action Description")
                }
            }.padding(.top, 14)
        }.font(.subheadline)
    }

    private func resultTitle(_ result: AfterAction) -> String {
        switch result {
        case .none: return action.gpt != nil ? String(localized: "Open Chat") : String(localized: "Ignore Output")
        case .paste: return String(localized: "Replace Selected Text")
        case .copy: return String(localized: "Copy to Clipboard")
        case .show: return String(localized: "Show Result")
        case .xshow: return String(localized: "Show and Allow Replacement")
        }
    }
}

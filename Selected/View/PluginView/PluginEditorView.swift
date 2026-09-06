import SwiftUI
import Yams

struct PluginEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let session: PluginEditorSession
    @ObservedObject var manager: PluginManager
    let didSave: (String) -> Void
    @State private var draft: Plugin
    @State private var source = ""
    @State private var mode = "Visual"
    @State private var section = "Basic Information"
    @State private var expandedAction: UUID?
    @State private var expandedOption: UUID?
    @State private var message: String?
    @State private var isError = false

    init(session: PluginEditorSession, manager: PluginManager, didSave: @escaping (String) -> Void) {
        self.session = session
        self.manager = manager
        self.didSave = didSave
        var draft = session.plugin
        if session.existing != nil {
            draft.info.version = draft.info.version.flatMap(PluginVersion.init)?.nextPatch ?? "1.0.0"
        }
        _draft = State(initialValue: draft)
        _expandedAction = State(initialValue: draft.actions.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title2).foregroundStyle(Color.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.09), in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.existing == nil ? String(localized: "Create Your Plugin") : String(localized: "Edit Plugin")).font(.title3.bold())
                    Text(session.existing == nil ? String(localized: "Start with an action and make it work your way.") : draft.info.name)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 16)
                PluginSegmentedControl(values: ["Visual", "YAML"], selection: Binding(get: { mode }, set: switchMode), title: { $0 == "Visual" ? String(localized: "Visual") : $0 })
                    .frame(width: 170)
            }.padding(24)
            Divider().opacity(0.5)
            if mode == "YAML" {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Switching to the visual editor parses and validates the YAML. Saving reformats it and removes comments.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $source)
                        .font(.system(.body, design: .monospaced)).autocorrectionDisabled()
                        .scrollContentBackground(.hidden).padding(14)
                        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)) }
                        .accessibilityLabel("Plugin YAML Definition")
                }.padding(24)
            } else {
                PluginSegmentedControl(values: ["Basic Information", "Actions", "Options"], selection: $section) { value in
                    switch value {
                    case "Actions": return String(localized: "Actions  ·  \(draft.actions.count)")
                    case "Options": return String(localized: "Options  ·  \(draft.info.options.count)")
                    default: return String(localized: "Basic Information")
                    }
                }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch section {
                        case "Actions": actions
                        case "Options": options
                        default: basicInfo
                        }
                    }.padding(24).frame(maxWidth: .infinity)
                }
            }
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 12) {
                if let message {
                    ScrollView {
                        Label(message, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.caption).foregroundStyle(isError ? Color.red : .secondary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 60)
                }
                HStack(spacing: 10) {
                    Button("Check Configuration", systemImage: "checkmark.shield") { validate() }
                        .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .buttonStyle(SettingsButtonStyle()).keyboardShortcut(.cancelAction)
                    Button(session.existing == nil ? String(localized: "Create Plugin") : String(localized: "Save Changes")) { save() }
                        .buttonStyle(SettingsButtonStyle(emphasis: .primary)).keyboardShortcut(.defaultAction)
                }
            }.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .tint(Color.blue)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
        .background(Color("SettingsBackground"))
        .frame(width: 760, height: 680)
        .interactiveDismissDisabled()
    }

    private var basicInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                SettingsField(title: String(localized: "Plugin Name")) {
                    TextField("For example: Reading Assistant", text: $draft.info.name)
                        .disabled(session.existing != nil && draft.info.identifier == nil)
                        .accessibilityLabel("Plugin Name")
                }
                SettingsField(title: String(localized: "Summary")) {
                    TextField("What can this plugin help you do?", text: $draft.info.description.text, axis: .vertical)
                        .lineLimit(2...3).accessibilityLabel("Plugin Description")
                }
                HStack(alignment: .top, spacing: 16) {
                    SettingsField(title: String(localized: "Version")) {
                        TextField("1.0.0", text: $draft.info.version.text).accessibilityLabel("Plugin Version")
                    }.frame(maxWidth: 180)
                    SettingsField(title: String(localized: "Icon")) {
                        TextField("symbol:bolt", text: $draft.info.icon).accessibilityLabel("Plugin Icon")
                    }
                }
                if let previous = session.existing?.info.version {
                    Label("Current version: \(previous). After saving, you can restore the previous version.", systemImage: "clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SettingsCard {
                DisclosureGroup("Advanced Settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsField(title: String(localized: "Stable Identifier")) {
                            TextField("com.example.plugin", text: $draft.info.identifier.text)
                                .disabled(session.existing != nil).accessibilityLabel("Stable Plugin Identifier")
                        }
                        if draft.info.identifier == nil {
                            Text("Legacy plugins use their name as the identifier. Keep the name unchanged to preserve existing settings.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        SettingsField(title: String(localized: "Minimum Selected Version · Optional")) {
                            TextField("No limit", text: $draft.info.minSelectedVersion.text)
                                .accessibilityLabel("Minimum Selected Version")
                        }
                        Text("You can also use text icons or files in the plugin package, such as file://./icon.png.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 16)
                }.font(.subheadline.weight(.medium))
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Choose actions to run on selected text.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(ActionKind.allCases) { kind in
                        Button(kind.title) {
                            let action = Action.new(kind: kind)
                            draft.actions.append(action)
                            expandedAction = action.id
                        }
                    }
                } label: {
                    Label("Add Action", systemImage: "plus")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.blue)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 9))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            ForEach($draft.actions) { $action in
                SettingsCard {
                    DisclosureGroup(isExpanded: Binding(get: { expandedAction == action.id }, set: { expandedAction = $0 ? action.id : nil })) {
                        VStack(alignment: .leading, spacing: 18) {
                            Divider().opacity(0.5)
                            PluginActionEditorView(action: $action)
                            Divider().opacity(0.5)
                            HStack(spacing: 4) {
                                Button("Move Up", systemImage: "arrow.up") { moveAction(action.id, by: -1) }
                                    .disabled(draft.actions.first?.id == action.id)
                                Button("Move Down", systemImage: "arrow.down") { moveAction(action.id, by: 1) }
                                    .disabled(draft.actions.last?.id == action.id)
                                Spacer()
                                Button("Delete Action", systemImage: "trash", role: .destructive) { draft.actions.removeAll { $0.id == action.id } }
                                    .buttonStyle(SettingsButtonStyle(emphasis: .destructive))
                            }.buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                        }.padding(.top, 14)
                    } label: {
                        HStack {
                            Label(action.meta.title.isEmpty ? String(localized: "Untitled Action") : action.meta.title, systemImage: "bolt")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(action.kind.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Define configurable fields, then enter their values on the details page.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("Add Option", systemImage: "plus") {
                    let option = Option(identifier: "option_" + UUID().uuidString.prefix(8), type: .string)
                    draft.info.options.append(option)
                    expandedOption = option.id
                }.buttonStyle(SettingsButtonStyle())
            }
            if draft.info.options.isEmpty {
                SettingsCard {
                    Label("No Options Yet", systemImage: "slider.horizontal.3").font(.headline)
                    Text("Add language choices, toggles, or secrets to customize your plugin.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach($draft.info.options) { $option in
                SettingsCard {
                    DisclosureGroup(isExpanded: Binding(get: { expandedOption == option.id }, set: { expandedOption = $0 ? option.id : nil })) {
                        VStack(alignment: .leading, spacing: 18) {
                            Divider().opacity(0.5)
                            PluginOptionEditorView(option: $option)
                            HStack {
                                Spacer()
                                Button("Delete Option", systemImage: "trash", role: .destructive) { draft.info.options.removeAll { $0.id == option.id } }
                                    .buttonStyle(SettingsButtonStyle(emphasis: .destructive))
                            }
                        }.padding(.top, 14)
                    } label: {
                        HStack {
                            Text(option.displayName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(option.type.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func switchMode(_ newMode: String) {
        do {
            if newMode == "YAML" { source = try YAMLEncoder().encode(draft) }
            else {
                let parsed = try YAMLDecoder().decode(Plugin.self, from: source)
                try parsed.validate()
                draft = parsed
                expandedAction = parsed.actions.first?.id
                expandedOption = nil
            }
            mode = newMode
            message = nil
        } catch { show(error) }
    }

    private func currentDraft() throws -> Plugin {
        let plugin = mode == "YAML" ? try YAMLDecoder().decode(Plugin.self, from: source) : draft
        try plugin.validate()
        return plugin
    }

    private func validate() {
        do {
            _ = try currentDraft()
            message = String(localized: "Configuration is valid. Version and identifier conflicts will be checked when saving.")
            isError = false
        } catch { show(error) }
    }

    private func save() {
        do {
            let plugin = try currentDraft()
            try manager.save(plugin, replacing: session.existing)
            didSave(plugin.id)
            dismiss()
        } catch { show(error) }
    }

    private func show(_ error: Error) {
        message = error.localizedDescription
        isError = true
    }

    private func moveAction(_ id: UUID, by offset: Int) {
        guard let index = draft.actions.firstIndex(where: { $0.id == id }) else { return }
        draft.actions.swapAt(index, index + offset)
    }
}

extension Binding where Value == String? {
    var text: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" }, set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

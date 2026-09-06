import SwiftUI

struct PluginOptionEditorView: View {
    @Binding var option: Option

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SettingsField(title: String(localized: "Display Name")) {
                TextField("For example: Output language", text: $option.label.text).accessibilityLabel("Option Display Name")
            }
            SettingsField(title: String(localized: "Option Identifier")) {
                TextField("language", text: $option.identifier).accessibilityLabel("Option Identifier")
            }
        }
        PluginSegmentedControl(values: OptionType.allCases, selection: $option.type, title: { $0.title })
            .onChange(of: option.type) {
                option.defaultVal = nil
                option.values = option.type == .multiple ? ["first", "second"] : nil
                option.valueLabels = nil
                option.multiline = nil
            }
        switch option.type {
        case .boolean:
            Toggle("Enabled by default", isOn: Binding(get: { option.defaultVal == "true" }, set: { option.defaultVal = $0.description }))
                .toggleStyle(.switch).controlSize(.small)
        case .multiple:
            PluginStringListField(title: String(localized: "Choices · Comma-separated"), values: $option.values)
                .onChange(of: option.values) {
                    if let value = option.defaultVal, option.values?.contains(value) != true { option.defaultVal = nil }
                }
            PluginStringListField(title: String(localized: "Display Labels · Optional, in the same order as the choices"), values: $option.valueLabels)
            SettingsMenuPicker(title: String(localized: "Default Value"), values: Array(Set(option.values ?? [])).sorted(),
                             selection: Binding(get: { option.defaultVal ?? option.values?.first ?? "" }, set: { option.defaultVal = $0 }), label: { $0 })
        case .string:
            SettingsField(title: String(localized: "Default Value")) {
                TextField("Leave empty for no default value", text: $option.defaultVal.text, axis: .vertical).accessibilityLabel("Option Default Value")
            }
            Toggle("Allow multiple lines", isOn: Binding(get: { option.multiline ?? false }, set: { option.multiline = $0 }))
                .toggleStyle(.switch).controlSize(.small)
        case .secret:
            Label("Enter the value on the plugin details page to save it to Keychain.", systemImage: "lock.shield")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        SettingsField(title: String(localized: "Instructions · Optional")) {
            TextField("Explain what users should enter", text: $option.description.text, axis: .vertical)
                .accessibilityLabel("Option Instructions")
        }
        if option.type == .string || option.type == .secret {
            Toggle("Required before running", isOn: Binding(get: { option.required == true }, set: { option.required = $0 }))
                .toggleStyle(.switch).controlSize(.small)
        }
    }
}

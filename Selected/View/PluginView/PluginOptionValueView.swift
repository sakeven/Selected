import SwiftUI

struct PluginOptionValueView: View {
    let pluginID: String
    let option: Option
    @ObservedObject var manager: PluginManager
    @FocusState private var isFocused: Bool
    @State private var text = ""
    @State private var savedText = ""
    @State private var didSave = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch option.type {
            case .boolean:
                HStack {
                    Text(option.displayName)
                    Spacer()
                    Toggle(option.displayName, isOn: Binding(get: { text == "true" }, set: { update($0.description) }))
                        .toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
            case .multiple:
                SettingsMenuPicker(title: option.displayName, values: option.values ?? [],
                                   selection: Binding(get: { text }, set: update), label: label(for:))
            case .string, .secret:
                HStack {
                    Text(option.displayName)
                    Spacer()
                    if text != savedText {
                        Button("Save", systemImage: "checkmark") { update(text) }
                            .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                            .help(option.type == .secret ? String(localized: "Save to Keychain") : String(localized: "Save this value"))
                    } else if didSave {
                        Label("Saved", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(minHeight: 24)
                if option.type == .secret {
                    SecureField("Enter \(option.displayName)", text: $text)
                        .focused($isFocused)
                        .textFieldStyle(.plain).padding(10)
                        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? Color.blue.opacity(0.6) : .primary.opacity(0.07), lineWidth: isFocused ? 1.5 : 1) }
                        .onSubmit { update(text) }
                        .accessibilityLabel(option.displayName)
                } else if option.multiline == true {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 90, maxHeight: 150)
                        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? Color.blue.opacity(0.6) : .primary.opacity(0.07), lineWidth: isFocused ? 1.5 : 1) }
                        .accessibilityLabel(option.displayName)
                } else {
                    TextField("Enter \(option.displayName)", text: $text)
                        .focused($isFocused)
                        .textFieldStyle(.plain).padding(10)
                        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? Color.blue.opacity(0.6) : .primary.opacity(0.07), lineWidth: isFocused ? 1.5 : 1) }
                        .onSubmit { update(text) }
                        .accessibilityLabel(option.displayName)
                }
            }
            if let description = option.description { Text(description).font(.caption).foregroundStyle(.secondary) }
            if option.required == true && savedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Required before running", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
            }
        }
        .onAppear {
            text = option.value(pluginID: pluginID)
            savedText = text
        }
    }

    private func label(for value: String) -> String {
        guard let index = option.values?.firstIndex(of: value), let labels = option.valueLabels, labels.indices.contains(index) else { return value }
        return labels[index]
    }

    private func update(_ value: String) {
        do {
            try option.save(value, pluginID: pluginID)
            text = value
            savedText = value
            didSave = true
            errorMessage = nil
            manager.optionValueChangeCnt += 1
        } catch { errorMessage = error.localizedDescription }
    }
}

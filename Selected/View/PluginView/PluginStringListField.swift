import SwiftUI

struct PluginStringListField: View {
    let title: String
    @Binding var values: [String]?
    @State private var text = ""

    var body: some View {
        SettingsField(title: title) {
            TextField("", text: $text).accessibilityLabel(title)
        }
            .onAppear { text = values?.joined(separator: ", ") ?? "" }
            .onChange(of: text) {
                let parsed = text.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                values = parsed.isEmpty ? nil : parsed
            }
    }
}

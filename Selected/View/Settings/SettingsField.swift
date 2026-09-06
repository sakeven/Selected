import SwiftUI

struct SettingsField<Content: View>: View {
    @FocusState private var isFocused: Bool
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            content
                .labelsHidden()
                .focused($isFocused)
                .textFieldStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035), in: .rect(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(isFocused ? Color.blue.opacity(0.6) : .primary.opacity(0.07), lineWidth: isFocused ? 1.5 : 1) }
        }
    }
}

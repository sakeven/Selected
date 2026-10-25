import SwiftUI

struct SettingsField<Content: View>: View {
    @FocusState private var isFocused: Bool
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium))
            content
                .labelsHidden()
                .accessibilityLabel(title)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.inset.opacity(0.65), in: .rect(cornerRadius: AppTheme.controlRadius))
                .overlay { RoundedRectangle(cornerRadius: AppTheme.controlRadius).strokeBorder(isFocused ? AppTheme.accent : AppTheme.border, lineWidth: isFocused ? 1.5 : 1) }
        }
    }
}

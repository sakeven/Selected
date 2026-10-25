import SwiftUI

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppTheme.surface, in: .rect(cornerRadius: AppTheme.cardRadius))
            .overlay { RoundedRectangle(cornerRadius: AppTheme.cardRadius).strokeBorder(AppTheme.border.opacity(0.7)) }
    }
}

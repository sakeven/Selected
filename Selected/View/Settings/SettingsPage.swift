import SwiftUI

struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(title: title, subtitle: subtitle)
                .padding(AppTheme.pageInset)
                .background(AppTheme.surface)
            Rectangle().fill(AppTheme.border).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    content
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(AppTheme.pageInset)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .background(AppTheme.canvas)
        .tint(AppTheme.accent)
        .toggleStyle(.switch)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
    }
}

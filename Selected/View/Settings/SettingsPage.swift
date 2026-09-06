import SwiftUI

struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(title: title, subtitle: subtitle).padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .background(Color("SettingsBackground"))
        .tint(.blue)
        .toggleStyle(.switch)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
    }
}

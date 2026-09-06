import SwiftUI

struct SettingsDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    configuration.label
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 7)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "已展开" : "已折叠")

            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

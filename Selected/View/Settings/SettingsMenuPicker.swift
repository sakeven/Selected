import SwiftUI

struct SettingsMenuPicker<Selection: Hashable>: View {
    let title: String
    let values: [Selection]
    @Binding var selection: Selection
    let label: (Selection) -> String

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Menu {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection = value
                    } label: {
                        if value == selection {
                            Label(label(value), systemImage: "checkmark")
                        } else {
                            Text(label(value))
                        }
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Text(label(selection))
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(AppTheme.inset.opacity(0.65), in: .rect(cornerRadius: AppTheme.controlRadius))
                .overlay { RoundedRectangle(cornerRadius: AppTheme.controlRadius).strokeBorder(AppTheme.border) }
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(title)
            .accessibilityValue(label(selection))
        }
    }
}

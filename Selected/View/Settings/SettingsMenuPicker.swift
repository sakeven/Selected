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
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(title)
            .accessibilityValue(label(selection))
        }
    }
}

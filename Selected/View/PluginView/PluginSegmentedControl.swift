import SwiftUI

struct PluginSegmentedControl<Selection: Hashable>: View {
    let values: [Selection]
    @Binding var selection: Selection
    let title: (Selection) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text(title(value))
                        .font(.subheadline.weight(selection == value ? .semibold : .regular))
                        .foregroundStyle(selection == value ? .primary : .secondary)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                            }
                        }
                        .contentShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.primary.opacity(0.045), in: .rect(cornerRadius: 11))
    }
}

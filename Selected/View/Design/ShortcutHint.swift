import SwiftUI

struct ShortcutHint: View {
    let keys: String
    var title: LocalizedStringKey? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 5)
                .frame(minWidth: 22, minHeight: 21)
                .background(AppTheme.surface, in: .rect(cornerRadius: 4))
                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(AppTheme.border) }
            if let title { Text(title).font(.caption) }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

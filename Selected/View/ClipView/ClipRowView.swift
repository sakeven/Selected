import SwiftUI

struct ClipRowView: View {
    @ObservedObject var clip: ClipHistoryData
    let isSelected: Bool
    let shortcutNumber: Int?
    @State private var isHovered = false
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.rowTitle)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(clip.appDisplayName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let date = clip.lastCopiedAt ?? clip.firstCopiedAt {
                        Text(date, format: calendar.isDateInToday(date) ? .dateTime.hour().minute() : .dateTime.month(.abbreviated).day())
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 45)
        .background(isSelected ? AppTheme.selection : isHovered ? AppTheme.inset : .clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(AppTheme.accent).frame(width: 3)
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityValue(clip.contentTypeLabel)
    }

    @ViewBuilder private var thumbnail: some View {
        if let shortcutNumber {
            ShortcutHint(keys: "⌘\(shortcutNumber)")
        } else if clip.displayKind == .image, let bytes = clip.primaryItem?.data, let image = NSImage(data: bytes) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: 4))
        } else if clip.displayKind == .color, let color = clip.colorValue {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: color))
                .strokeBorder(AppTheme.border, lineWidth: 0.5)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: clip.displayKind.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

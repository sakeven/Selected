import SwiftUI

struct ClipRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var clip: ClipHistoryData
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: [
                        clip.displayKind.tint.opacity(colorScheme == .dark ? 0.25 : 0.13),
                        clip.displayKind.tint.opacity(colorScheme == .dark ? 0.12 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 34, height: 36)
                .overlay {
                    if clip.displayKind == .image,
                       let imageData = clip.primaryItem?.data,
                       let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 36)
                            .clipShape(.rect(cornerRadius: 10))
                    } else if clip.displayKind == .color, let color = clip.colorValue {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(nsColor: color))
                            .padding(3)
                    } else {
                        ClipKindIcon(kind: clip.displayKind)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(clip.displayKind.tint.opacity(0.12), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(clip.rowTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    Text(clip.contentTypeLabel)
                    Text("·")
                    Text(clip.appDisplayName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text("clip.pinned"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? colorScheme.clipSelectedFill : (isHovered ? colorScheme.clipCardFill : .clear))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct ClipKindIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    let kind: ClipDisplayKind

    var body: some View {
        Image(kind.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(kind.tint)
            .brightness(colorScheme == .dark ? 0.16 : 0)
    }
}

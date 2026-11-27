import SwiftUI

struct ClipRowView: View {
    @ObservedObject var clip: ClipHistoryData
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(clip.displayKind.tint.opacity(0.12))
                .frame(width: 38, height: 40)
                .overlay {
                    if clip.displayKind == .image,
                       let imageData = clip.primaryItem?.data,
                       let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 40)
                            .clipShape(.rect(cornerRadius: 10))
                    } else if clip.displayKind == .color, let color = clip.colorValue {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(nsColor: color))
                            .padding(4)
                    } else {
                        Image(clip.displayKind.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(clip.displayKind.tint)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? AppTheme.accent.opacity(0.25) : AppTheme.border, lineWidth: 0.5)
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

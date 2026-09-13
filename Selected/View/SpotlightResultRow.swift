import SwiftUI

struct SpotlightResultRow: View {
    let item: SpotlightItem
    let isSelected: Bool
    let run: () -> Void
    let preview: (URL) -> Void
    let reveal: (URL) -> Void

    var body: some View {
        Button(action: run) {
            HStack(spacing: 12) {
                Group {
                    if let url = item.url {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable().scaledToFit()
                    } else if case .action(let action) = item.content {
                        Icon(action.actionMeta.icon)
                    } else if case .clipboard(let clip) = item.content {
                        Image(clip.displayKind.imageName).resizable().scaledToFit()
                    } else if case .more = item.content {
                        Image(systemName: "ellipsis").font(.title2).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "text.cursor").font(.title2)
                    }
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).lineLimit(1)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if case .textActions = item.content {
                    Text("⇥").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                }
                Image(systemName: "return").font(.caption).foregroundStyle(.secondary)
                    .opacity(isSelected ? 1 : 0).accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            if let url = item.url {
                Button("Open", systemImage: "arrow.up.forward.app", action: run)
                if case .file = item.content {
                    Button("Quick Look", systemImage: "eye") { preview(url) }
                }
                Button("Show in Finder", systemImage: "folder") { reveal(url) }
                Button("Copy Path", systemImage: "doc.on.doc") { copyText(url.path) }
            } else if case .clipboard(let clip) = item.content {
                Button("clip.paste", systemImage: "return", action: run)
                Button("clip.copy", systemImage: "doc.on.doc") {
                    ClipService.shared.restore(clip) { SpotlightWindowManager.shared.forceCloseWindow() }
                }
            }
        }
    }
}

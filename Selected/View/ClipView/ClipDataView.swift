import SwiftUI

struct ClipDataView: View {
    @ObservedObject var data: ClipHistoryData
    let onTogglePin: () -> Void
    @State private var showsOriginalFormatting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(data.contentTypeLabel, systemImage: data.displayKind.symbolName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
                if [.html, .richText].contains(data.displayKind), data.hasReadableText {
                    Picker("Preview format", selection: $showsOriginalFormatting) {
                        Text("Reading view").tag(false)
                        Text("Original formatting").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }
                Button(action: onTogglePin) {
                    Label(data.isPinned ? String(localized: "clip.unpin") : String(localized: "clip.pin"),
                          systemImage: data.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(AppIconButtonStyle())
                .help(Text(data.isPinned ? "clip.unpin" : "clip.pin") + Text(verbatim: "  ⌘P"))
            }

            ClipPreviewStage(data: data, showsOriginalFormatting: showsOriginalFormatting)
                .id(data.contentDigest)
                .padding(.top, 18)
                .padding(.bottom, 16)

            ClipMetadataCard(data: data)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct ClipMetadataCard: View {
    @ObservedObject var data: ClipHistoryData
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = data.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }
            Text(data.appDisplayName)
            Text("·").accessibilityHidden(true)
            Text(data.lastCopiedText ?? data.firstCopiedText)
                .accessibilityLabel(Text(LocalizedStringKey(data.lastCopiedText == nil ? "Date:" : "Last copied:")) + Text(" ") + Text(data.lastCopiedText ?? data.firstCopiedText))
            Spacer(minLength: 0)
            Label(data.copiesText, systemImage: "doc.on.doc")
                .help("Copied:")
                .accessibilityLabel(Text("Copied:") + Text(" ") + Text(data.copiesText))
            Button("clip.details", systemImage: "info.circle") { showDetails = true }
                .labelStyle(.iconOnly)
                .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                .controlSize(.small)
                .help("clip.details")
                .popover(isPresented: $showDetails) {
                    details.padding(20).frame(width: 380)
                }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            applicationRow

            ClipMetadataRow(title: "Date:") {
                Text(data.firstCopiedText)
            }

            if let lastCopiedText = data.lastCopiedText {
                ClipMetadataRow(title: "Last copied:") {
                    Text(lastCopiedText)
                }
            }

            ClipMetadataRow(title: "Copied:") {
                Text(data.copiesText)
            }

            if let locationInfo = data.locationInfo {
                ClipMetadataRow(title: "\(locationInfo.title):") {
                    Text(locationInfo.value)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var applicationRow: some View {
        ClipMetadataRow(title: "Application:") {
            HStack(spacing: 8) {
                if let icon = data.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text(data.appDisplayName)
                    .font(.body.weight(.medium))
            }
        }
    }
}

private struct ClipMetadataRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(LocalizedStringKey(title))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Spacer(minLength: 0)

            content
                .font(.body)
                .foregroundStyle(colorScheme.clipPrimaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

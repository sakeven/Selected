import SwiftUI
import PDFKit

struct ClipPreviewStage: View {
    @ObservedObject var data: ClipHistoryData
    let showsOriginalFormatting: Bool

    var body: some View {
        Group {
            switch data.displayKind {
            case .color:
                ClipColorPreview(data: data)
            case .file:
                ClipFilePreview(data: data)
            case .image:
                ClipImagePreview(data: data)
            case .link:
                ClipLinkPreview(data: data)
            case .text, .richText, .html, .unknown:
                ClipTextPreview(data: data, showsOriginalFormatting: showsOriginalFormatting)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipColorPreview: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.rowTitle)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
            if let color = data.colorValue {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .fill(Color(nsColor: color))
                    .overlay { RoundedRectangle(cornerRadius: AppTheme.controlRadius).strokeBorder(AppTheme.border) }
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ClipFilePreview: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let url = data.fileURLValue {
            if url.pathExtension.lowercased() == "pdf" {
                PDFKitRepresentedView(url: url)
            } else {
                QuickLookPreview(url: url)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Image("ClipboardFile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(ClipDisplayKind.file.tint)
                    .accessibilityHidden(true)

                Text(data.detailTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ClipImagePreview: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let imageData = data.primaryItem?.data,
           let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            VStack(spacing: 14) {
                Image("ClipboardImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(ClipDisplayKind.image.tint)
                    .accessibilityHidden(true)

                Text(data.detailTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipLinkPreview: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        let address = data.displayURLString ?? data.detailTitle
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: address)
                    .textSelection(.enabled)
                if isValidHttpUrl(address), let url = URL(string: address) {
                    if let previewText = data.cleanedPreviewText, previewText != address {
                        Text(previewText)
                            .textSelection(.enabled)
                    }

                    Link(destination: url) {
                        Label("clip.link.open", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(.link)
                    .font(.body)
                    .help(address)
                }
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ClipTextPreview: View {
    @ObservedObject var data: ClipHistoryData
    var showsOriginalFormatting = false

    private var rtfText: NSAttributedString? {
        guard let rtfData = data.rtfData else { return nil }
        return try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }

    var body: some View {
        let useOriginal = showsOriginalFormatting || !data.hasReadableText
        if useOriginal, let htmlData = data.htmlData {
            HTMLView(htmlData: htmlData, baseURL: data.url.flatMap(URL.init(string:)))
        } else if useOriginal, let rtfText {
            RTFView(text: rtfText)
        } else if let plainText = data.plainText, !plainText.isEmpty {
            TextView(text: plainText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(data.detailTitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

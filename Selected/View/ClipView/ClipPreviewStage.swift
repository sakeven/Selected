import SwiftUI
import PDFKit

struct ClipPreviewStage: View {
    @ObservedObject var data: ClipHistoryData

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
                ClipTextPreview(data: data)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipColorPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width * 0.56, geometry.size.height * 0.9)

            HStack {
                Spacer()
                Circle()
                    .fill(data.colorValue.map(Color.init(nsColor:)) ?? .green)
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(colorScheme.clipSelectedStroke, lineWidth: 1)
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipFilePreview: View {
    @Environment(\.colorScheme) private var colorScheme
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
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(data.displayKind.tint)

                Text(data.detailTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(colorScheme.clipPrimaryText)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(colorScheme.clipSecondaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ClipImagePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        if let imageData = data.primaryItem?.data,
           let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundStyle(colorScheme.clipPrimaryText.opacity(0.84))

                Text(data.detailTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colorScheme.clipPrimaryText)
                    .lineLimit(2)

                if let locationInfo = data.locationInfo {
                    Text(locationInfo.value)
                        .font(.body)
                        .foregroundStyle(colorScheme.clipSecondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipLinkPreview: View {
    @ObservedObject var data: ClipHistoryData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let urlString = data.displayURLString,
               let url = URL(string: urlString),
               isValidHttpUrl(urlString) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(.teal)
                        .frame(width: 44, height: 44)
                        .background(.teal.opacity(0.1), in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)

                    Text(url.host() ?? data.detailTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Text(urlString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)

                if let previewText = data.cleanedPreviewText,
                   previewText != urlString {
                    Text(previewText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }

                Link(destination: url) {
                    Label("clip.link.open", systemImage: "arrow.up.right")
                }
                .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                .help(urlString)
            } else {
                Text(data.displayURLString ?? data.detailTitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ClipTextPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var data: ClipHistoryData

    private var rtfText: NSAttributedString? {
        guard let rtfData = data.rtfData else { return nil }
        return try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }

    var body: some View {
        if let htmlData = data.htmlData {
            HTMLView(htmlData: htmlData, baseURL: data.url.flatMap(URL.init(string:)))
        } else if let rtfText {
            RTFView(text: rtfText)
        } else if let plainText = data.plainText, !plainText.isEmpty {
            TextView(text: plainText, font: data.isJSON ? .monospacedSystemFont(ofSize: 14, weight: .regular) : .systemFont(ofSize: 14))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(data.detailTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(colorScheme.clipSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

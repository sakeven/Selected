import AppKit
import Foundation

func format(_ d: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter.string(from: d)
}

func isValidHttpUrl(_ string: String) -> Bool {
    guard let url = URL(string: string) else {
        return false
    }

    guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
        return false
    }

    return url.host != nil
}

extension ClipHistoryData {
    func matchesSearch(_ query: String) -> Bool {
        if query.isEmpty { return true }
        if let plainText, plainText.localizedCaseInsensitiveContains(query) { return true }
        if let url, url.localizedCaseInsensitiveContains(query) { return true }
        if let fileName = fileURLValue?.lastPathComponent.removingPercentEncoding,
           fileName.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    var htmlData: Data? {
        getItems().first { $0.type == NSPasteboard.PasteboardType.html.rawValue }?.data
    }

    var rtfData: Data? {
        getItems().first { $0.type == NSPasteboard.PasteboardType.rtf.rawValue }?.data
    }

    var primaryItem: ClipHistoryItem? {
        getItems().first
    }

    var primaryPasteboardType: NSPasteboard.PasteboardType? {
        guard let type = primaryItem?.type else { return nil }
        return NSPasteboard.PasteboardType(rawValue: type)
    }

    var displayKind: ClipDisplayKind {
        guard let type = primaryPasteboardType else {
            if let plainText = plainText, isValidHttpUrl(plainText) {
                return .link
            }
            return plainText == nil ? .unknown : .text
        }

        switch type {
        case .color:
            return .color
        case .png, .tiff:
            return .image
        case .fileURL:
            return .file
        case .URL:
            return .link
        case .string, .rtf, .html, NSPasteboard.PasteboardType("org.chromium.source-url"):
            if htmlData != nil { return .html }
            if rtfData != nil { return .richText }
            if let plainText = plainText, isValidHttpUrl(plainText) {
                return .link
            }
            return .text
        default:
            return url == nil ? .unknown : .link
        }
    }

    var contentTypeLabel: String {
        displayKind.label
    }

    var cleanedPreviewText: String? {
        guard let plainText else { return nil }
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var rowTitle: String {
        switch displayKind {
        case .color:
            return String(localized: "Color")
        case .file:
            return fileURLValue?.lastPathComponent.removingPercentEncoding ?? "File"
        case .image:
            return imageSizeText.map { "\(String(localized: "Image")) \($0)" } ?? String(localized: "Image")
        case .link:
            return displayURLString ?? cleanedPreviewText?.removingAllNewlines() ?? "Link"
        case .text, .richText, .html:
            return cleanedPreviewText?.removingAllNewlines() ?? contentTypeLabel
        case .unknown:
            return cleanedPreviewText?.removingAllNewlines() ?? displayURLString ?? "Clipboard Item"
        }
    }

    var detailTitle: String {
        switch displayKind {
        case .file:
            return fileURLValue?.lastPathComponent.removingPercentEncoding ?? rowTitle
        default:
            return rowTitle
        }
    }

    var fileURLValue: URL? {
        guard primaryPasteboardType == .fileURL,
              let data = primaryItem?.data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return URL(string: string)
    }

    var displayURLString: String? {
        if displayKind == .file {
            if let fileURLValue {
                return fileURLValue.path.removingPercentEncoding ?? fileURLValue.path
            }
            return nil
        }

        if let url, !url.isEmpty {
            return url
        }

        if let cleanedPreviewText, isValidHttpUrl(cleanedPreviewText) {
            return cleanedPreviewText
        }

        return nil
    }

    var imageSizeText: String? {
        guard let data = primaryItem?.data,
              let image = NSImage(data: data) else {
            return nil
        }

        let width = valueFormatter.string(from: NSNumber(value: Double(image.size.width))) ?? ""
        let height = valueFormatter.string(from: NSNumber(value: Double(image.size.height))) ?? ""
        guard !width.isEmpty, !height.isEmpty else { return nil }
        return "\(width) × \(height)"
    }

    var colorValue: NSColor? {
        guard let data = primaryItem?.data else { return nil }
        return decodeNSColor(from: data)
    }

    var appDisplayName: String {
        guard let bundleID = application,
              let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return "Unknown"
        }
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    var appIcon: NSImage? {
        guard let bundleID = application,
              let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: bundleURL.path)
    }

    var firstCopiedText: String {
        firstCopiedAt.map(format) ?? "-"
    }

    var lastCopiedText: String? {
        guard numberOfCopies > 1, let lastCopiedAt else { return nil }
        return format(lastCopiedAt)
    }

    var copiesText: String {
        if numberOfCopies == 1 {
            return "1"
        }
        return String(format: String(localized: "%d times"), numberOfCopies)
    }

    var locationInfo: (title: String, value: String)? {
        switch displayKind {
        case .file:
            guard let fileURLValue else { return nil }
            return ("Path", fileURLValue.path.removingPercentEncoding ?? fileURLValue.path)
        case .image:
            guard let imageSizeText else { return nil }
            return ("Size", imageSizeText)
        case .link:
            guard let displayURLString else { return nil }
            return ("URL", displayURLString)
        default:
            return nil
        }
    }
}

extension ClipHistoryData {
    var isJSON: Bool {
        guard let text = plainText else { return false }
        return JSONFormatter.isValidJSON(text)
    }
}

extension String {
    func removingAllNewlines() -> String {
        self
            .replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }
}

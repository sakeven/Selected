import SwiftUI

enum ClipDisplayKind {
    case color
    case file
    case image
    case link
    case text
    case richText
    case html
    case unknown

    var tint: Color {
        switch self {
        case .text: .teal
        case .link: AppTheme.accent
        case .file: .orange
        case .image: .pink
        case .richText: .purple
        case .html: .indigo
        case .color: .mint
        case .unknown: .secondary
        }
    }

    var label: String {
        switch self {
        case .color: return String(localized: "Color")
        case .file: return String(localized: "File")
        case .image: return String(localized: "Image")
        case .link: return String(localized: "Link")
        case .text: return String(localized: "Plain Text")
        case .richText: return String(localized: "Rich Text")
        case .html: return String(localized: "HTML")
        case .unknown: return String(localized: "Clipboard Item")
        }
    }

    var imageName: String {
        switch self {
        case .color: return "ClipboardColor"
        case .file, .unknown: return "ClipboardFile"
        case .image: return "ClipboardImage"
        case .link: return "ClipboardLink"
        case .text: return "ClipboardText"
        case .richText: return "ClipboardRichText"
        case .html: return "ClipboardHTML"
        }
    }
}

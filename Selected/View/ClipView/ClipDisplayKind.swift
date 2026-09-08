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

    var tint: Color {
        switch self {
        case .color: return .green
        case .file: return .blue
        case .image: return .orange
        case .link: return .teal
        case .text: return .blue
        case .richText: return .cyan
        case .html: return .mint
        case .unknown: return .gray
        }
    }

    var symbolName: String {
        switch self {
        case .color: return "circle.fill"
        case .file: return "doc.on.doc"
        case .image: return "photo"
        case .link: return "link"
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "circle.dashed.rectangle"
        case .unknown: return "doc"
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

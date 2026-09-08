import AppKit

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: NSPasteboard.PasteboardType) {
        if let desc = descriptionOfPasteboardType[value] {
            appendInterpolation(desc)
        } else {
            appendInterpolation("unknown")
        }
    }
}

let descriptionOfPasteboardType: [NSPasteboard.PasteboardType: String]  = [
    .color: "Color",
    .URL: "URL",
    .png: "PNG image",
    .html: "HTML",
    .pdf: "PDF",
    .rtf: "rich text format",
    .string: "plain text",
    .fileURL: "file",
    .tiff: "tagged image file format"
]

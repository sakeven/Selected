import Foundation

struct AIFileAttachment: Sendable {
    let filename: String
    let data: Data
    var mimeType: String = "application/pdf"
}

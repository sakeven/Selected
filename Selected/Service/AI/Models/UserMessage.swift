import Foundation

public class UserMessage{
    let text: String
    let images: [Data]
    let files: [AIFileAttachment]

    init(text: String, images: [Data] = [], files: [AIFileAttachment] = []) {
        self.text = text
        self.images = images
        self.files = files
    }
}

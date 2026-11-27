import Foundation

extension ClipHistoryData {
    func getItems() -> [ClipHistoryItem] {
        if let items = items {
            return items.array as! [ClipHistoryItem]
        }
        return []
    }

    var contentDigest: String {
        MD5(chunks: getItems().compactMap(\.data))
    }
}

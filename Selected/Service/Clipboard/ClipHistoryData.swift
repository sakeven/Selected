import Foundation
import CryptoKit

extension ClipHistoryData {
    func getItems() -> [ClipHistoryItem] {
        if let items = items {
            return items.array as! [ClipHistoryItem]
        }
        return []
    }

    func MD5() -> String {
        var md5 = Insecure.MD5()
        for item in getItems(){
            md5.update(data: item.data!)
        }
        let digest = md5.finalize()
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}

import Foundation
import CryptoKit

func MD5(string: String) -> String {
    var md5 = Insecure.MD5()
    md5.update(data: Data(string.utf8))
    let digest = md5.finalize()
    return digest.map {
        String(format: "%02hhx", $0)
    }.joined()
}

import Foundation
import CryptoKit

func MD5(string: String) -> String {
    MD5(chunks: [Data(string.utf8)])
}

func MD5(chunks: [Data]) -> String {
    var md5 = Insecure.MD5()
    for chunk in chunks { md5.update(data: chunk) }
    let digest = md5.finalize()
    return digest.map {
        String(format: "%02hhx", $0)
    }.joined()
}

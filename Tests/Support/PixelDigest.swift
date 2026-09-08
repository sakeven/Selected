import AppKit
import CryptoKit

struct PixelDigest: Codable, Equatable {
    let width: Int
    let height: Int
    let sha256: String

    init(image: CGImage) {
        width = image.width
        height = image.height
        var pixels = Data(count: width * height * 4)
        let width = width
        let height = height
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        sha256 = SHA256.hash(data: pixels).map { String(format: "%02x", $0) }.joined()
    }
}

import AppKit

// NSImage -> JPEG
extension NSImage {
    func jpegData(compression: CGFloat = 0.85) -> Data? {
        guard
            let tiff = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compression]
        )
    }

    // MARK: - 1. 计算目标尺寸（只缩小，不放大）

    /// 根据 OpenAI 要求计算等比缩放后的尺寸（短边 ≤ maxShortSide，长边 ≤ maxLongSide）
    func scaledSizeForOpenAI(
        maxShortSide: CGFloat = 768,
        maxLongSide: CGFloat = 2000
    ) -> CGSize? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width  = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let minSide = min(width, height)
        let maxSide = max(width, height)

        // 同时满足短边、长边限制，并且不放大
        let scale = min(
            1.0,
            maxShortSide / minSide,
            maxLongSide / maxSide
        )

        return CGSize(
            width: (width * scale).rounded(),
            height: (height * scale).rounded()
        )
    }

    // MARK: - 2. 按指定尺寸等比缩放

    /// 将 NSImage 缩放到指定像素尺寸（使用 CG 重绘）
    func resized(to targetSize: CGSize) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let targetWidth = Int(targetSize.width)
        let targetHeight = Int(targetSize.height)

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let scaledCGImage = ctx.makeImage() else {
            return nil
        }

        return NSImage(
            cgImage: scaledCGImage,
            size: targetSize   // 这里的 size 不用于像素计算，只是 NSImage 的逻辑尺寸
        )
    }

    // MARK: - 3. 在给定最大体积下做 JPEG 压缩

    /// 在给定最大字节数下，尝试不同 compression，返回满足限制的 JPEG Data
    func jpegData(
        maxBytes: Int,
        initialCompression: CGFloat = 0.9,
        minCompression: CGFloat = 0.3,
        step: CGFloat = 0.1
    ) -> Data? {
        var compression = initialCompression

        while compression >= minCompression {
            if let data = jpegData(compression: compression),
               data.count <= maxBytes {
                return data
            }
            compression -= step
        }

        // 兜底：返回最小压缩质量（即使略超）
        return jpegData(compression: minCompression)
    }

    // MARK: - 4. 总入口：符合 OpenAI 要求的 Data

    /// 按 OpenAI 尺寸 + 体积限制生成 JPEG Data
    func openAIReadyImageData(
        maxShortSide: CGFloat = 768,
        maxLongSide: CGFloat = 2000,
        maxBytes: Int = 2 * 1024 * 1024
    ) -> Data? {
        // 1. 计算目标尺寸
        guard let targetSize = scaledSizeForOpenAI(
            maxShortSide: maxShortSide,
            maxLongSide: maxLongSide
        ) else {
            return nil
        }

        // 2. 缩放
        guard let resizedImage = resized(to: targetSize) else {
            return nil
        }

        // 3. 按体积限制压缩
        return resizedImage.jpegData(maxBytes: maxBytes)
    }
}

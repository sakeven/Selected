import AppKit
import Testing
@testable import Selected

struct AIImageTests {
    @Test func smallImagesAreNotUpscaledAndLargeImagesKeepAspectRatio() throws {
        #expect(try image(width: 120, height: 80).scaledSizeForOpenAI() == CGSize(width: 120, height: 80))
        #expect(try image(width: 1600, height: 1200).scaledSizeForOpenAI() == CGSize(width: 1024, height: 768))
        #expect(try image(width: 4000, height: 1000).scaledSizeForOpenAI() == CGSize(width: 2000, height: 500))
        #expect(try image(width: 1000, height: 4000).scaledSizeForOpenAI() == CGSize(width: 500, height: 2000))
    }

    @Test func encodedAttachmentRemainsJPEGWithRequestedPixelSize() throws {
        let original = try image(width: 400, height: 300)
        let data = try #require(original.openAIReadyImageData(maxShortSide: 60, maxLongSide: 100))
        #expect(data.starts(with: [0xFF, 0xD8]))
        let decoded = try #require(NSBitmapImageRep(data: data))
        #expect(decoded.pixelsWide == 80)
        #expect(decoded.pixelsHigh == 60)
    }

    @Test func tinyByteLimitKeepsExistingMinimumQualityFallback() throws {
        let data = try #require(image(width: 16, height: 16).jpegData(maxBytes: 1))
        #expect(data.count > 1)
        #expect(NSImage(data: data) != nil)
    }

    private func image(width: Int, height: Int) throws -> NSImage {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        memset(bitmap.bitmapData, 0xFF, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(bitmap)
        return image
    }
}

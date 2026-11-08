import AppKit
import ImageIO
import Testing
@testable import Compositor

/// The flattened PSD export: a valid Photoshop file another app opens as the picture.
@MainActor
struct PSDExportTests {
    /// A small image whose pixels are given row by row, top first, premultiplied as the canvas keeps them.
    private func image(width: Int, height: Int, _ pixels: [(UInt8, UInt8, UInt8, UInt8)]) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        for (index, pixel) in pixels.enumerated() {
            bytes[index * 4] = pixel.0; bytes[index * 4 + 1] = pixel.1
            bytes[index * 4 + 2] = pixel.2; bytes[index * 4 + 3] = pixel.3
        }
        return try #require(context.makeImage())
    }
    private func u16(_ data: Data, _ offset: Int) -> Int { Int(data[offset]) << 8 | Int(data[offset + 1]) }
    private func u32(_ data: Data, _ offset: Int) -> Int {
        (Int(data[offset]) << 24) | (Int(data[offset + 1]) << 16) | (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
    }

    @Test func theFileIsAnUncompressedRGBAPhotoshopFile() throws {
        let data = try PSDWriter.flattened(image(width: 4, height: 3, Array(repeating: (255, 0, 0, 255), count: 12)))
        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "8BPS")
        #expect(u16(data, 4) == 1 && u16(data, 12) == 4 && u16(data, 22) == 8 && u16(data, 24) == 3)
        #expect(u32(data, 14) == 3 && u32(data, 18) == 4, "height, then width")
        #expect(u32(data, 26) == 0 && u32(data, 30) == 0 && u32(data, 34) == 0)
        #expect(u16(data, 38) == 0, "uncompressed")
        #expect(data.count == 40 + 4 * 12, "one plane a channel, top row first")
    }

    /// Alpha is stored straight, not premultiplied: a half-transparent red pixel keeps a full red.
    @Test func alphaIsStoredStraight() throws {
        let data = try PSDWriter.flattened(image(width: 1, height: 1, [(128, 0, 0, 128)]))
        #expect(data[40] == 255, "red: \(data[40])")
        #expect(data[41] == 0 && data[42] == 0)
        #expect(data[43] == 128, "alpha: \(data[43])")
    }

    @Test func anotherReaderOpensItAsThePicture() throws {
        let source = try image(width: 3, height: 2, [
            (255, 0, 0, 255), (0, 255, 0, 255), (0, 0, 255, 255),
            (255, 255, 0, 255), (255, 0, 255, 255), (0, 255, 255, 255),
        ])
        let data = try PSDWriter.flattened(source)
        let imageSource = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(decoded.width == 3 && decoded.height == 2)
        let context = try #require(CGContext(data: nil, width: 3, height: 2, bitsPerComponent: 8, bytesPerRow: 12,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        // Top first, as the file stores its rows.
        context.translateBy(x: 0, y: 2)
        context.scaleBy(x: 1, y: -1)
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: 3, height: 2))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        for pixel in 0..<6 {
            let expected: [UInt8] = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255],
                                     [255, 255, 0, 255], [255, 0, 255, 255], [0, 255, 255, 255]][pixel]
            let actual = (0..<4).map { bytes[pixel * 4 + $0] }
            #expect(zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 1 }, "pixel \(pixel): \(actual)")
        }
    }
}

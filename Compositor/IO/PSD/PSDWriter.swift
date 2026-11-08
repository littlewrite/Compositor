import CoreGraphics
import Foundation

/// Writes the flattened picture as a Photoshop file: RGB, 8 bits a channel, with alpha, uncompressed. A PSD's first
/// channel data is what apps show before they can read layers, and this file has none: the picture as the canvas shows
/// it, ready for another app to open, place or print.
nonisolated enum PSDWriter {
    static func flattened(_ image: CGImage) throws -> Data {
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= DocumentLimits.maxSide, height <= DocumentLimits.maxSide,
              let pixels = try straightPixels(of: image) else { throw ExportError.encode }
        var file = Data(capacity: 26 + 12 + width * height * 4)
        file.append(contentsOf: Array("8BPS".utf8))
        append(UInt16(1), to: &file)                    // Version 1.
        file.append(contentsOf: [UInt8](repeating: 0, count: 6))
        append(UInt16(4), to: &file)                    // Red, green, blue and alpha.
        append(UInt32(height), to: &file)
        append(UInt32(width), to: &file)
        append(UInt16(8), to: &file)                    // 8 bits a channel.
        append(UInt16(3), to: &file)                    // RGB.
        for _ in 0..<3 { append(UInt32(0), to: &file) } // No color mode data, image resources or layers.
        append(UInt16(0), to: &file)                    // Uncompressed.
        // The channels one after another, each top row first, as the format stores a merged image.
        for channel in 0..<4 {
            for y in 0..<height {
                let row = y * width * 4 + channel
                for x in 0..<width { file.append(pixels[row + x * 4]) }
            }
        }
        return file
    }

    /// The picture's pixels straight, not premultiplied, top row first.
    private static func straightPixels(of image: CGImage) throws -> [UInt8]? {
        let context = try BrushRaster.context(width: image.width, height: image.height, mask: false)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else { return nil }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let count = image.width * image.height * 4
        var pixels = [UInt8](repeating: 0, count: count)
        for i in stride(from: 0, to: count, by: 4) {
            let alpha = Int(bytes[i + 3])
            guard alpha > 0, alpha < 255 else {
                pixels[i] = bytes[i]; pixels[i + 1] = bytes[i + 1]; pixels[i + 2] = bytes[i + 2]; pixels[i + 3] = UInt8(alpha)
                continue
            }
            for k in 0..<3 { pixels[i + k] = UInt8(min(255, Int(bytes[i + k]) * 255 / alpha)) }
            pixels[i + 3] = UInt8(alpha)
        }
        return pixels
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
}

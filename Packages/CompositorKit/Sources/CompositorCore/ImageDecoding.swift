import CoreGraphics
import CoreImage
import ImageIO
import Foundation

/// Turns a file on disk into a display-sized image. RAW goes through Core Image's camera engine,
/// everything else through ImageIO's downsampling, so a 24-megapixel file never lands at full size
/// in an editor that only shows a few hundred points of it.
public enum ImageDecoding {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    private static let rawExtensions: Set<String> = [
        "arw", "dng", "cr2", "cr3", "nef", "raf", "orf", "rw2", "pef", "srw",
        "3fr", "erf", "kdc", "mef", "mos", "nrw", "sr2", "x3f", "rwl",
    ]

    public static func isRaw(_ url: URL) -> Bool {
        rawExtensions.contains(url.pathExtension.lowercased())
    }

    public static func decode(contentsOf url: URL, maxDimension: CGFloat = 2400) -> CGImage? {
        if isRaw(url), let raw = decodeRaw(contentsOf: url, maxDimension: maxDimension) {
            return raw
        }
        return downsample(contentsOf: url, maxDimension: maxDimension)
    }

    private static func decodeRaw(contentsOf url: URL, maxDimension: CGFloat) -> CGImage? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }
        let longest = max(filter.nativeSize.width, filter.nativeSize.height)
        if longest > maxDimension {
            filter.scaleFactor = Float(maxDimension / longest)
            filter.isDraftModeEnabled = true
        }
        guard let output = filter.outputImage else { return nil }
        return context.createCGImage(output, from: output.extent)
    }

    private static func downsample(contentsOf url: URL, maxDimension: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

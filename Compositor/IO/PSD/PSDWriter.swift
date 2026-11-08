import CoreGraphics
import Foundation

/// One layer of a layered Photoshop file, ready to write: its pixels and mask straight (not premultiplied), its
/// rectangle on the canvas, and how it blends. A folder is two records, a divider below its children and the folder
/// record above them, as Photoshop stores groups.
nonisolated struct PSDWriteLayer: @unchecked Sendable {
    enum Role: Equatable { case pixels, folder, divider }

    let role: Role
    let name: String
    let isVisible: Bool
    let opacity: Double
    let blendMode: LayerBlendMode
    /// The layer's rectangle in the file's own pixels, a whole number of them; empty for a folder or divider.
    let bounds: CGRect
    /// Four bytes a pixel in red, green, blue and alpha order, straight alpha, top row first, `bounds`' size. Nil for a
    /// folder or divider.
    let pixels: [UInt8]?
    /// One byte a pixel at `bounds`' size, white where the layer shows. Nil for no mask.
    let mask: [UInt8]?
    let maskDisabled: Bool
}

/// Writes Photoshop files: the flattened picture alone, or the document's layers with the flattened picture beside
/// them for apps that can't read layers. RGB, 8 bits a channel, with alpha, uncompressed.
nonisolated enum PSDWriter {
    static func flattened(_ image: CGImage) throws -> Data {
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= DocumentLimits.maxSide, height <= DocumentLimits.maxSide,
              let pixels = try straightPixels(of: image) else { throw ExportError.encode }
        var file = header(width: width, height: height, layerSection: 0)
        appendMerged(pixels, width: width, height: height, to: &file)
        return file
    }

    /// The document's layers, bottom record first, over a merged picture of the whole canvas. `merged` must be the
    /// file's size: it's what an app that reads no layers shows.
    static func layered(width: Int, height: Int, layers: [PSDWriteLayer], merged: CGImage) throws -> Data {
        guard width > 0, height > 0, width == merged.width, height == merged.height,
              width <= DocumentLimits.maxSide, height <= DocumentLimits.maxSide,
              layers.count <= Int(Int16.max), let mergedPixels = try straightPixels(of: merged) else { throw ExportError.encode }
        var layerInfo = Data()
        append(Int16(layers.count), to: &layerInfo)
        for layer in layers { appendRecord(layer, to: &layerInfo) }
        for layer in layers { appendChannels(layer, to: &layerInfo) }
        if layerInfo.count % 2 == 1 { layerInfo.append(0) }
        var section = Data(capacity: layerInfo.count + 8)
        append(UInt32(layerInfo.count), to: &section)
        section.append(layerInfo)
        append(UInt32(0), to: &section) // No global layer mask.
        var file = header(width: width, height: height, layerSection: section.count)
        file.append(section)
        appendMerged(mergedPixels, width: width, height: height, to: &file)
        return file
    }

    /// The header through the three sections' lengths, the third of which is the layer and mask section's size.
    private static func header(width: Int, height: Int, layerSection: Int) -> Data {
        var file = Data(capacity: 26 + layerSection + width * height * 4)
        file.append(contentsOf: Array("8BPS".utf8))
        append(UInt16(1), to: &file)                    // Version 1.
        file.append(contentsOf: [UInt8](repeating: 0, count: 6))
        append(UInt16(4), to: &file)                    // Red, green, blue and alpha.
        append(UInt32(height), to: &file)
        append(UInt32(width), to: &file)
        append(UInt16(8), to: &file)                    // 8 bits a channel.
        append(UInt16(3), to: &file)                    // RGB.
        append(UInt32(0), to: &file)                    // No color mode data.
        append(UInt32(0), to: &file)                    // No image resources.
        append(UInt32(layerSection), to: &file)
        return file
    }

    /// The picture as the merged image data: uncompressed, its channels one after another and each top row first.
    private static func appendMerged(_ pixels: [UInt8], width: Int, height: Int, to file: inout Data) {
        append(UInt16(0), to: &file)
        for channel in 0..<4 {
            for y in 0..<height {
                let row = y * width * 4 + channel
                for x in 0..<width { file.append(pixels[row + x * 4]) }
            }
        }
    }

    private static func appendRecord(_ layer: PSDWriteLayer, to data: inout Data) {
        let box = layer.bounds.integral
        append(Int32(clamping: Int(box.minY)), to: &data)
        append(Int32(clamping: Int(box.minX)), to: &data)
        append(Int32(clamping: Int(box.maxY)), to: &data)
        append(Int32(clamping: Int(box.maxX)), to: &data)
        let ids = channelIDs(layer)
        append(UInt16(ids.count), to: &data)
        let channelLength = 2 + Int(box.width) * Int(box.height)
        for id in ids {
            append(id, to: &data)
            append(UInt32(channelLength), to: &data)
        }
        data.append(contentsOf: Array("8BIM".utf8))
        data.append(contentsOf: Array(blendKey(layer.blendMode).utf8))
        data.append(UInt8(clamping: Int((min(1, max(0, layer.opacity)) * 255).rounded())))
        data.append(0)                                   // No clipping.
        data.append(layer.isVisible ? 0 : 2)             // Bit 1 hides the layer.
        data.append(0)                                   // Filler.
        let extra = extraData(layer)
        append(UInt32(extra.count), to: &data)
        data.append(extra)
    }

    /// The transparency, color channels and user mask, in Photoshop's order.
    private static func channelIDs(_ layer: PSDWriteLayer) -> [Int16] {
        guard layer.pixels != nil else { return [] }
        return layer.mask == nil ? [-1, 0, 1, 2] : [-1, 0, 1, 2, -2]
    }

    private static func appendChannels(_ layer: PSDWriteLayer, to data: inout Data) {
        guard let pixels = layer.pixels else { return }
        let count = Int(layer.bounds.width) * Int(layer.bounds.height)
        for offset in [3, 0, 1, 2] {
            append(UInt16(0), to: &data)                 // Uncompressed.
            for index in 0..<count { data.append(pixels[index * 4 + offset]) }
        }
        if let mask = layer.mask {
            append(UInt16(0), to: &data)
            data.append(contentsOf: mask.prefix(count))
        }
    }

    private static func extraData(_ layer: PSDWriteLayer) -> Data {
        let box = layer.bounds.integral
        var extra = Data()
        if layer.mask != nil {
            append(UInt32(20), to: &extra)
            append(Int32(clamping: Int(box.minY)), to: &extra)
            append(Int32(clamping: Int(box.minX)), to: &extra)
            append(Int32(clamping: Int(box.maxY)), to: &extra)
            append(Int32(clamping: Int(box.maxX)), to: &extra)
            extra.append(255)                            // What lies outside it shows.
            extra.append(layer.maskDisabled ? 2 : 0)     // Bit 1 disables the mask.
            extra.append(contentsOf: [0, 0])
        } else {
            append(UInt32(0), to: &extra)
        }
        append(UInt32(0), to: &extra)                    // No blending ranges.
        appendName(layer.name, to: &extra)
        var unicode = Data()
        let units = Array(layer.name.utf16)
        append(UInt32(units.count), to: &unicode)
        for unit in units { append(unit, to: &unicode) }
        appendAdditional("luni", unicode, to: &extra)
        if layer.role != .pixels {
            var section = Data()
            append(UInt32(layer.role == .divider ? 3 : 1), to: &section)
            section.append(contentsOf: Array("8BIM".utf8))
            section.append(contentsOf: Array((layer.role == .divider ? "norm" : blendKey(layer.blendMode)).utf8))
            appendAdditional("lsct", section, to: &extra)
        }
        return extra
    }

    /// The name as a Pascal string, padded so the block is a whole number of words.
    private static func appendName(_ name: String, to data: inout Data) {
        let bytes = Array(name.utf8.prefix(255))
        data.append(UInt8(bytes.count))
        data.append(contentsOf: bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: (4 - (1 + bytes.count) % 4) % 4))
    }

    private static func appendAdditional(_ key: String, _ payload: Data, to data: inout Data) {
        data.append(contentsOf: Array("8BIM".utf8))
        data.append(contentsOf: Array(key.utf8))
        append(UInt32(payload.count), to: &data)
        data.append(payload)
        if payload.count % 2 == 1 { data.append(0) }
    }

    /// Photoshop's four-character key for a blend mode.
    private static func blendKey(_ mode: LayerBlendMode) -> String {
        switch mode {
        case .normal: "norm"
        case .darken: "dark"
        case .multiply: "mul "
        case .colorBurn: "idiv"
        case .linearBurn: "lbrn"
        case .lighten: "lite"
        case .screen: "scrn"
        case .colorDodge: "div "
        case .linearDodge: "lddg"
        case .overlay: "over"
        case .softLight: "sLit"
        case .hardLight: "hLit"
        case .vividLight: "vLit"
        case .linearLight: "lLit"
        case .pinLight: "pLit"
        case .hardMix: "hMix"
        case .difference: "diff"
        case .exclusion: "smud"
        case .subtract: "fsub"
        case .divide: "fdiv"
        case .hue: "hue "
        case .saturation: "sat "
        case .color: "colr"
        case .luminosity: "lum "
        }
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

import CoreGraphics
import Foundation

/// Builds the records a layered Photoshop export writes from a project: every layer's pixels drawn where its transform
/// puts them at the export's size, its mask beside them and its effects baked in. A folder becomes Photoshop's two
/// records — a divider below its children and the folder above them. Adjustment layers have no pixels of their own and
/// aren't written as layers; the merged picture keeps their look.
nonisolated enum PSDLayerExport {
    static func layers(for snapshot: ProjectSnapshot, width: Int, height: Int) throws -> [PSDWriteLayer] {
        let documentWidth = CGFloat(snapshot.manifest.width), documentHeight = CGFloat(snapshot.manifest.height)
        guard width > 0, height > 0, documentWidth > 0, documentHeight > 0 else { throw ExportError.encode }
        let scaleX = CGFloat(width) / documentWidth, scaleY = CGFloat(height) / documentHeight
        let all = snapshot.documentLayers
        func emit(parent: UUID?) throws -> [PSDWriteLayer] {
            var result: [PSDWriteLayer] = []
            for layer in all where layer.parentID == parent {
                if layer.isGroup {
                    result.append(record(role: .divider, name: "</Layer group>"))
                    result += try emit(parent: layer.id)
                    result.append(PSDWriteLayer(role: .folder, name: layer.name, isVisible: layer.isVisible,
                                                opacity: layer.opacity, blendMode: layer.blendMode, bounds: .zero,
                                                pixels: nil, mask: nil, maskDisabled: false))
                } else if let asset = layer.asset,
                          let pixels = try pixels(layer, image: asset.image, scaleX: scaleX, scaleY: scaleY) {
                    result.append(pixels)
                }
            }
            return result
        }
        return try emit(parent: nil)
    }

    private static func record(role: PSDWriteLayer.Role, name: String) -> PSDWriteLayer {
        PSDWriteLayer(role: role, name: name, isVisible: true, opacity: 1, blendMode: .normal, bounds: .zero,
                      pixels: nil, mask: nil, maskDisabled: false)
    }

    private static func pixels(_ layer: ImageLayer, image: CGImage, scaleX: CGFloat, scaleY: CGFloat) throws -> PSDWriteLayer? {
        let transform = layer.transform
        guard transform.isValid else { return nil }
        // The layer's mask, laid over its own pixels, hides part of it before the effects are made.
        let aligned = layer.mask.flatMap {
            $0.isEnabled ? $0.clipImage(placement: $0.placement, over: transform, width: image.width, height: image.height) : nil
        }
        let effects = LayerEffectsRenderer.cached(image, mask: aligned, effects: layer.effects)
        let source = effects?.image ?? image
        let placed = effects.map { LayerEffectsRenderer.placed(transform, image: $0.image, inset: $0.inset) } ?? transform
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)].map { corner in
            let point = corner.applying(placed.unitToDocument)
            return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        let minX = corners.map(\.x).min()!.rounded(.down), maxX = corners.map(\.x).max()!.rounded(.up)
        let minY = corners.map(\.y).min()!.rounded(.down), maxY = corners.map(\.y).max()!.rounded(.up)
        let width = max(1, Int(maxX - minX)), height = max(1, Int(maxY - minY))
        guard width <= DocumentLimits.maxSide, height <= DocumentLimits.maxSide,
              width * height <= DocumentLimits.maxSurfacePixels,
              minX > -2_000_000, minY > -2_000_000, maxX < 2_000_000, maxY < 2_000_000 else { throw ExportError.tooLarge }
        let bounds = CGRect(x: minX, y: minY, width: CGFloat(width), height: CGFloat(height))
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.translateBy(x: -minX, y: CGFloat(height) + minY)
        context.scaleBy(x: scaleX, y: -scaleY)
        LayerRenderer.draw(source, transform: placed, center: placed.center, opacity: 1, blendMode: .normal, mask: nil, in: context)
        guard let data = context.data else { throw ExportError.render }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let count = width * height
        var rgba = [UInt8](repeating: 0, count: count * 4)
        for i in stride(from: 0, to: count * 4, by: 4) {
            let alpha = Int(bytes[i + 3])
            guard alpha > 0, alpha < 255 else {
                rgba[i] = bytes[i]; rgba[i + 1] = bytes[i + 1]; rgba[i + 2] = bytes[i + 2]; rgba[i + 3] = UInt8(alpha)
                continue
            }
            for k in 0..<3 { rgba[i + k] = UInt8(min(255, Int(bytes[i + k]) * 255 / alpha)) }
            rgba[i + 3] = UInt8(alpha)
        }
        // An effect's own picture has the mask already in it; without effects the mask is written beside the pixels.
        let mask = effects == nil ? try aligned.map { try gray($0, transform: placed, scaleX: scaleX, scaleY: scaleY,
                                                               bounds: bounds, width: width, height: height) } : nil
        return PSDWriteLayer(role: .pixels, name: layer.name, isVisible: layer.isVisible, opacity: layer.opacity,
                             blendMode: layer.blendMode, bounds: bounds, pixels: rgba, mask: mask, maskDisabled: false)
    }

    /// The mask drawn where the layer's pixels are, one byte a pixel, white where the layer shows.
    private static func gray(_ image: CGImage, transform: LayerTransform, scaleX: CGFloat, scaleY: CGFloat,
                             bounds: CGRect, width: Int, height: Int) throws -> [UInt8] {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw ExportError.render }
        context.translateBy(x: -bounds.minX, y: CGFloat(height) + bounds.minY)
        context.scaleBy(x: scaleX, y: -scaleY)
        context.interpolationQuality = .high
        context.translateBy(x: transform.center.x, y: transform.center.y)
        context.rotate(by: transform.radians)
        context.scaleBy(x: transform.flipX ? -1 : 1, y: transform.flipY ? 1 : -1)
        context.draw(image, in: CGRect(x: -transform.size.width / 2, y: -transform.size.height / 2,
                                       width: transform.size.width, height: transform.size.height))
        guard let data = context.data else { throw ExportError.render }
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height))
    }
}

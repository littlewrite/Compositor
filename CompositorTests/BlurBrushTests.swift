import CoreGraphics
import Foundation
import Testing
@testable import Compositor

/// The Blur brush softens by its own Radius, whatever its size and strength.
@MainActor
struct BlurBrushTests {
    /// A hard vertical edge, blurred with one stroke along it: how many columns it spreads over.
    private func spread(radius: CGFloat, diameter: CGFloat = 60, strength: CGFloat = 1) throws -> Int {
        let session = EditorSession()
        session.createDocument(width: 200, height: 100)
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Edge"))
        session.selectTool(.blur)
        session.blurMode = .blur
        session.brushSettings.diameter = diameter
        session.brushSettings.hardness = 1
        session.brushSettings.opacity = strength
        session.brushSettings.blurRadius = radius
        session.beginBrush(at: CGPoint(x: 100, y: 20))
        session.continueBrush(at: CGPoint(x: 100, y: 80))
        session.finishBrushImmediately()
        let result = try BrushRaster.copy(try #require(session.activeLayer?.asset?.image))
        let data = try #require(result.data).assumingMemoryBound(to: UInt8.self)
        // Columns along row 50 that are neither black nor white any more.
        return (0..<200).filter { let v = data[50 * result.bytesPerRow + $0 * 4]; return v > 10 && v < 245 }.count
    }

    @Test func radiusSetsHowFarItSoftens() throws {
        let narrow = try spread(radius: 2), wide = try spread(radius: 12)
        #expect(wide > narrow * 2, "a wider radius spreads the edge further: \(narrow) against \(wide)")
        // Brush size and strength don't change the reach.
        #expect(try spread(radius: 12, diameter: 80) == wide)
    }

    /// Sharpen brings out an edge: the shoulders of a soft edge stroked along it move apart, and pixels beyond the
    /// brush stay as they were.
    @Test func sharpenSteepensASoftEdge() throws {
        func ramp(_ x: Int) -> UInt8 {
            let t = min(1, max(0, Double(x - 97) / 6))
            return UInt8((60 + (t * t * (3 - 2 * t)) * 135).rounded())
        }
        func stroke(gpu: Bool) throws -> [UInt8] {
            let context = try BrushRaster.context(width: 200, height: 100, mask: false)
            let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
            for y in 0..<100 { for x in 0..<200 {
                let value = ramp(x)
                let i = y * context.bytesPerRow + x * 4
                pixels[i] = value; pixels[i + 1] = value; pixels[i + 2] = value; pixels[i + 3] = 255
            } }
            let image = try #require(context.makeImage())
            let layer = ImageLayer(asset: ImportedImage(image: image, thumbnail: image, name: "Edge"), origin: .zero)
            var settings = BrushSettings()
            settings.diameter = 60
            settings.hardness = 1
            settings.opacity = 1
            let stroke = try WarpStroke(layer: layer, image: image, transform: layer.transform,
                                        canvas: CGSize(width: 200, height: 100), mode: .sharpen, settings: settings,
                                        useGPU: gpu)
            for y in stride(from: 20.0, through: 80, by: 4) { stroke.append(CGPoint(x: 100, y: y)) }
            let result = try BrushRaster.copy(try #require(stroke.image))
            let data = try #require(result.data).assumingMemoryBound(to: UInt8.self)
            return (0..<200).map { data[50 * result.bytesPerRow + $0 * 4] }
        }
        for gpu in [false, true] where gpu == false || GPUCanvasRenderer.shared != nil {
            let sharpened = try stroke(gpu: gpu)
            let side = gpu ? "on the GPU" : "on the CPU"
            #expect(sharpened[98] < ramp(98) - 3, "the dark shoulder darkens \(side): \(sharpened[98]) from \(ramp(98))")
            #expect(sharpened[102] > ramp(102) + 3, "the bright shoulder brightens \(side): \(sharpened[102]) from \(ramp(102))")
            #expect(sharpened[20] == ramp(20), "beyond the brush the edge is untouched: \(sharpened[20])")
        }
    }
}

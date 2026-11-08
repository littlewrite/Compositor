import AppKit
import Testing
@testable import Compositor

/// Satin and Bevel & Emboss, the two layer effects that shade inside a layer's own edge.
@MainActor
struct SatinBevelTests {
    private func whiteSquare(size: Int = 40) throws -> CGImage {
        let context = try BrushRaster.context(width: size, height: size, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return try #require(context.makeImage())
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: try #require(context.data).assumingMemoryBound(to: UInt8.self),
                                         count: image.width * image.height * 4))
    }

    @Test func satinDefaultsAndValidation() {
        let satin = SatinEffect()
        #expect(satin.isEnabled && satin.isValid)
        var bad = satin
        bad.opacity = 2
        #expect(!bad.isValid)
        bad = satin
        bad.size = -1
        #expect(!bad.isValid)
    }

    @Test func bevelDefaultsAndValidation() {
        let bevel = BevelEffect()
        #expect(bevel.isEnabled && bevel.isValid)
        #expect(bevel.color == PaletteColor(red: 1, green: 1, blue: 1))
        #expect(bevel.shadowColor == PaletteColor(red: 0, green: 0, blue: 0))
        var bad = bevel
        bad.depth = 10_000
        #expect(!bad.isValid)
    }

    @Test func effectsCarryTheirSheenAndBevel() throws {
        var effects = LayerEffects()
        effects.satin = SatinEffect()
        effects.bevel = BevelEffect()
        #expect(effects.contains(.satin) && effects.contains(.bevel))
        #expect(effects.isEnabled(.satin) && effects.isEnabled(.bevel))
        #expect(!effects.runsOnGPU, "the CPU draws these two")
        let decoded = try JSONDecoder().decode(LayerEffects.self, from: JSONEncoder().encode(effects))
        #expect(decoded == effects)
        effects.remove(.satin)
        effects.remove(.bevel)
        #expect(effects.isEmpty)
    }

    /// Satin shades the edge away from where the layer's shape was moved.
    @Test func satinShadesTheSideFacingAwayFromTheMove() throws {
        let source = try whiteSquare()
        var satin = SatinEffect()
        satin.angle = 0
        satin.distance = 10
        satin.size = 6
        satin.red = 0; satin.green = 0; satin.blue = 0
        satin.opacity = 1
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(satin: satin))
        let image = rendered.image, inset = Int(rendered.inset)
        let values = try pixels(image)
        func pixel(_ x: Int, _ y: Int) -> UInt8 { values[((y + inset) * image.width + (x + inset)) * 4] }
        #expect(pixel(20, 20) > 240, "the middle keeps its color: \(pixel(20, 20))")
        #expect(pixel(38, 20) < 200, "the far edge is shaded: \(pixel(38, 20))")
        #expect(values[(inset * image.width + inset) * 4 + 3] == 255, "the corners keep their alpha")
    }

    /// The bevel's shadow falls on the side away from the light and its highlight on the side facing it.
    @Test func bevelShadowsTheSideAwayFromTheLight() throws {        let source = try whiteSquare()
        var bevel = BevelEffect()
        bevel.angle = 90
        bevel.depth = 10
        bevel.size = 4
        bevel.opacity = 1
        bevel.shadowRed = 0; bevel.shadowGreen = 0; bevel.shadowBlue = 0
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(bevel: bevel))
        let image = rendered.image, inset = Int(rendered.inset)
        let values = try pixels(image)
        func pixel(_ x: Int, _ y: Int) -> UInt8 { values[((y + inset) * image.width + (x + inset)) * 4] }
        #expect(pixel(20, 20) > 240, "the middle keeps its color: \(pixel(20, 20))")
        #expect(pixel(20, 37) < 200, "the far edge is shaded: \(pixel(20, 37))")
        #expect(pixel(20, 3) > 240, "the lit edge stays bright: \(pixel(20, 3))")
    }

    /// A ninety-degree gradient overlay runs from its start color at the top to its end color at the bottom.
    @Test func gradientOverlayRunsTopToBottomAtNinety() throws {
        let source = try whiteSquare()
        var gradient = GradientOverlayEffect()
        gradient.angle = 90
        gradient.startRed = 0; gradient.startGreen = 0; gradient.startBlue = 0
        gradient.endRed = 1; gradient.endGreen = 1; gradient.endBlue = 1
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(gradientOverlay: gradient))
        let image = rendered.image, inset = Int(rendered.inset)
        let values = try pixels(image)
        func pixel(_ x: Int, _ y: Int) -> UInt8 { values[((y + inset) * image.width + (x + inset)) * 4] }
        #expect(pixel(20, 2) < 40, "the start color at the top: \(pixel(20, 2))")
        #expect(pixel(20, 37) > 215, "the end color at the bottom: \(pixel(20, 37))")
        var reversed = gradient
        reversed.reversed = true
        let flipped = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(gradientOverlay: reversed)).image
        let flippedValues = try pixels(flipped)
        func flippedPixel(_ x: Int, _ y: Int) -> UInt8 { flippedValues[((y + inset) * flipped.width + (x + inset)) * 4] }
        #expect(flippedPixel(20, 37) < 40, "reversed puts the start at the bottom: \(flippedPixel(20, 37))")
        #expect(flippedPixel(20, 2) > 215, "and the end at the top: \(flippedPixel(20, 2))")
    }

    @Test func sheenAndBevelPersistThroughAProject() async throws {
        let session = EditorSession()
        session.createDocument(width: 20, height: 20)
        let image = try whiteSquare(size: 20)
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Layer"))
        let id = try #require(session.activeLayerID)
        guard let index = session.document?.layers.firstIndex(where: { $0.id == id }) else { return }
        session.document?.layers[index].effects = LayerEffects(gradientOverlay: GradientOverlayEffect(),
                                                               satin: SatinEffect(), bevel: BevelEffect())
        let snapshot = try #require(session.projectSnapshot())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SatinBevel-\(UUID()).comp")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.shared.save(snapshot, to: url)
        let loaded = try await ProjectStore.shared.load(from: url)
        let record = try #require(loaded.manifest.layers.first { $0.id == id })
        #expect(record.effects?.gradientOverlay != nil && record.effects?.satin != nil && record.effects?.bevel != nil)
    }
}

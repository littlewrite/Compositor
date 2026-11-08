import AppKit
import Testing
@testable import Compositor

/// Pattern Overlay repeats one of the built-in tiles over a layer's own pixels.
@MainActor
struct PatternOverlayTests {
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

    @Test func defaultsAndValidation() {
        let pattern = PatternOverlayEffect()
        #expect(pattern.isEnabled && pattern.isValid)
        #expect(pattern.pattern == .dots)
        var bad = pattern
        bad.scale = 0
        #expect(!bad.isValid)
        bad = pattern
        bad.opacity = 2
        #expect(!bad.isValid)
        bad = pattern
        bad.angle = 400
        #expect(!bad.isValid)
    }

    @Test func theEffectJoinsTheLayersStyles() throws {
        var effects = LayerEffects(patternOverlay: PatternOverlayEffect())
        #expect(effects.contains(.patternOverlay))
        #expect(effects.isEnabled(.patternOverlay))
        #expect(!effects.runsOnGPU, "the CPU draws the pattern")
        #expect(!effects.isEmpty && effects.isValid)
        let decoded = try JSONDecoder().decode(LayerEffects.self, from: JSONEncoder().encode(effects))
        #expect(decoded == effects)
        effects.remove(.patternOverlay)
        #expect(effects.isEmpty)
    }

    /// The checkerboard's dark cells land inside the layer, and its light cells keep the layer's color.
    @Test func thePatternTilesAcrossTheLayer() throws {
        let source = try whiteSquare()
        var pattern = PatternOverlayEffect()
        pattern.pattern = .checkerboard
        pattern.scale = 25
        pattern.red = 0; pattern.green = 0; pattern.blue = 0
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(patternOverlay: pattern))
        let image = rendered.image, inset = Int(rendered.inset)
        let values = try pixels(image)
        var darkest = 255, lightest = 0
        for y in 0..<40 {
            for x in 0..<40 {
                let index = ((y + inset) * image.width + (x + inset)) * 4
                darkest = min(darkest, Int(values[index]))
                lightest = max(lightest, Int(values[index]))
                #expect(values[index + 3] == 255, "the layer keeps its alpha")
            }
        }
        #expect(darkest < 40, "the pattern's ink shows: \(darkest)")
        #expect(lightest > 215, "the layer's own color shows between cells: \(lightest)")
    }

    /// Turning the pattern leaves the picture inside the layer and still tiled.
    @Test func aTurnedPatternStillCoversTheLayer() throws {
        let source = try whiteSquare()
        var pattern = PatternOverlayEffect()
        pattern.pattern = .stripes
        pattern.scale = 50
        pattern.angle = 45
        pattern.red = 0; pattern.green = 0; pattern.blue = 0
        let rendered = try LayerEffectsRenderer.render(source, mask: nil, effects: LayerEffects(patternOverlay: pattern))
        let image = rendered.image, inset = Int(rendered.inset)
        let values = try pixels(image)
        let middle = ((20 + inset) * image.width + (20 + inset)) * 4
        var different = 0
        for y in 0..<40 {
            for x in 0..<40 {
                let index = ((y + inset) * image.width + (x + inset)) * 4
                if values[index] != values[middle] { different += 1 }
            }
        }
        #expect(different > 200, "the turned stripes cross the layer: \(different)")
        #expect(values[middle + 3] == 255)
    }

    @Test func thePatternChoiceReadsAndWritesTheEffect() throws {
        let choice = try #require(EffectControls.choices[.patternOverlay])
        #expect(choice.titles == PatternPreset.allCases.map(\.displayName))
        var effects = LayerEffects(patternOverlay: PatternOverlayEffect())
        #expect(choice.titles[choice.chosen(effects)] == PatternPreset.dots.displayName)
        let stripes = try #require(PatternPreset.allCases.firstIndex(of: .stripes))
        choice.choose(&effects, stripes)
        #expect(effects.patternOverlay?.pattern == .stripes)
    }

    @Test func aPatternSurvivesAProject() async throws {
        let session = EditorSession()
        session.createDocument(width: 20, height: 20)
        let image = try whiteSquare(size: 20)
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Layer"))
        let id = try #require(session.activeLayerID)
        var pattern = PatternOverlayEffect()
        pattern.pattern = .diamonds
        pattern.angle = 30
        pattern.scale = 175
        guard let index = session.document?.layers.firstIndex(where: { $0.id == id }) else { return }
        session.document?.layers[index].effects = LayerEffects(patternOverlay: pattern)
        let snapshot = try #require(session.projectSnapshot())
        #expect(snapshot.manifest.version == ProjectManifest.current)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PatternOverlay-\(UUID()).comp")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.shared.save(snapshot, to: url)
        let loaded = try await ProjectStore.shared.load(from: url)
        let record = try #require(loaded.manifest.layers.first { $0.id == id })
        #expect(record.effects?.patternOverlay == pattern)
    }
}

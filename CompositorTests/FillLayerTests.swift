import AppKit
import Testing
@testable import Compositor

/// Fill layers cover the canvas, and stay fills: filling one again takes the new color.
@MainActor
struct FillLayerTests {
    private func session() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 120, height: 80)
        return session
    }
    private func pixel(_ session: EditorSession, x: Int = 60, y: Int = 40) async throws -> [Int] {
        let image = try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (y * image.width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }

    @Test func addFillLayerCoversTheCanvasInOneUndo() async throws {
        let session = session()
        session.setPaletteColor(PaletteColor(red: 0.2, green: 0.4, blue: 0.6), background: false)
        let count = session.history.undoCount
        session.addFillLayer()
        #expect(session.history.undoCount == count + 1 && session.history.undoName == "Solid Color Fill")
        let layer = try #require(session.activeLayer)
        #expect(layer.name == "Color Fill 1" && layer.size == CGSize(width: 120, height: 80))
        #expect(layer.liveFill?.content == .solid(PaletteColor(red: 0.2, green: 0.4, blue: 0.6)))
        #expect(try await pixel(session) == [51, 102, 153, 255])
        session.undo()
        #expect(session.document?.layers.isEmpty == true)
    }

    @Test func fillingItAgainTakesTheColor() async throws {
        let session = session()
        session.setPaletteColor(PaletteColor(red: 1, green: 0, blue: 0), background: false)
        session.addFillLayer()
        let layer = try #require(session.activeLayer)
        session.setPaletteColor(PaletteColor(red: 0, green: 0, blue: 1), background: true)
        let count = session.history.undoCount
        await session.fillSelection(with: .background)
        #expect(session.history.undoCount == count + 1 && session.history.undoName == "Fill Color")
        #expect(session.document?.layers.count == 1 && session.activeLayerID == layer.id)
        #expect(session.activeLayer?.liveFill?.content == .solid(PaletteColor(red: 0, green: 0, blue: 1)))
        #expect(try await pixel(session) == [0, 0, 255, 255])
        session.undo()
        #expect(try await pixel(session) == [255, 0, 0, 255])
    }

    /// A Gradient fill runs foreground to background, top to bottom, and its gradient stays with the layer.
    @Test func aGradientFillRunsFromItsColors() async throws {
        let session = session()
        session.setPaletteColor(.white, background: false)
        session.setPaletteColor(.black, background: true)
        let count = session.history.undoCount
        session.addGradientFillLayer()
        #expect(session.history.undoCount == count + 1 && session.history.undoName == "Gradient Fill")
        let layer = try #require(session.activeLayer)
        #expect(layer.name == "Gradient Fill 1")
        guard case .gradient(let gradient) = try #require(layer.liveFill?.content) else {
            Issue.record("the layer is a gradient fill")
            return
        }
        #expect(gradient.startColor == .white && gradient.endColor == .black)
        #expect(try await pixel(session, x: 60, y: 4)[0] > 230, "the top is white")
        #expect(try await pixel(session, x: 60, y: 75)[0] < 25, "the bottom is black")
        // Filling a gradient with a color paints over it, as it would any pixels: only a color fill takes the color.
        session.setPaletteColor(PaletteColor(red: 1, green: 0, blue: 0), background: false)
        await session.fillSelection(with: .foreground)
        #expect(session.activeLayer?.liveFill == nil)
    }

    @Test func paintingOnItMakesItPlainPixels() throws {
        let session = session()
        session.addFillLayer()
        #expect(session.activeLayer?.liveFill != nil)
        session.selectTool(.brush)
        session.setPaletteColor(.white, background: false)
        session.beginBrush(at: CGPoint(x: 60, y: 40))
        session.finishBrushImmediately()
        #expect(session.activeLayer?.liveFill == nil, "the pixels are no longer the fill's")
    }

    @Test func rasterizingEndsTheFill() async throws {
        let session = session()
        session.addFillLayer()
        #expect(session.canRasterizeLayer)
        session.rasterizeLayer()
        #expect(session.history.undoName == "Rasterize Layer")
        #expect(session.activeLayer?.fill == nil && session.activeLayer?.liveFill == nil)
        #expect(try await pixel(session) == [0, 0, 0, 255], "the pixels stay")
    }

    @Test func aReopenedProjectKeepsTheFillEditable() async throws {
        let session = session()
        session.addFillLayer(color: PaletteColor(red: 0.1, green: 0.2, blue: 0.3))
        session.addGradientFillLayer()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("comp")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.shared.save(try #require(session.projectSnapshot()), to: url)
        let snapshot = try await ProjectStore.shared.load(from: url)
        let color = try #require(snapshot.documentLayers.first { $0.name == "Color Fill 1" })
        #expect(color.liveFill?.content == .solid(PaletteColor(red: 0.1, green: 0.2, blue: 0.3)))
        let gradient = try #require(snapshot.documentLayers.first { $0.name == "Gradient Fill 1" })
        #expect(gradient.liveFill?.content.isSolid == false)
    }
}

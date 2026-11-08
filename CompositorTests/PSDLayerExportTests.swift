import AppKit
import ImageIO
import Testing
@testable import Compositor

/// The layered PSD export: the document's layers, with their names, places, masks, opacity and blend modes, over the
/// merged picture another app shows.
@MainActor
struct PSDLayerExportTests {
    private func solid(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, width: Int, height: Int) throws -> CGImage {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    private func gray(_ value: CGFloat, width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: value, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    /// A 100×80 document with a red 40×30 layer at (10, 10) and a blue 20×20 one at (60, 40) above it.
    private func makeSession() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 100, height: 80)
        let red = try solid(1, 0, 0, width: 40, height: 30)
        session.insert(ImportedImage(image: red, thumbnail: red, name: "Red"))
        let redID = try #require(session.activeLayerID)
        setTransform(session, redID, origin: CGPoint(x: 10, y: 10), size: CGSize(width: 40, height: 30))
        let blue = try solid(0, 0, 1, width: 20, height: 20)
        session.insert(ImportedImage(image: blue, thumbnail: blue, name: "Blue"))
        let blueID = try #require(session.activeLayerID)
        setTransform(session, blueID, origin: CGPoint(x: 60, y: 40), size: CGSize(width: 20, height: 20))
        return session
    }

    private func setTransform(_ session: EditorSession, _ id: UUID, origin: CGPoint, size: CGSize) {
        guard let index = session.document?.layers.firstIndex(where: { $0.id == id }) else { return }
        session.document?.layers[index].transform = LayerTransform(origin: origin, size: size)
    }

    private func export(_ session: EditorSession) throws -> PSDDocument {
        let snapshot = try #require(session.projectSnapshot())
        let merged = try solid(0.5, 0.5, 0.5, width: 100, height: 80)
        let layers = try PSDLayerExport.layers(for: snapshot, width: 100, height: 80)
        let data = try PSDWriter.layered(width: 100, height: 80, layers: layers, merged: merged)
        return try PSDReader.read(data)
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (y * image.width + x) * 4
        return (0..<4).map { bytes[offset + $0] }
    }

    @Test func layersArriveWithTheirNamesPlacesAndModes() throws {
        let session = try makeSession()
        let layer = try #require(session.activeLayer)
        guard let index = session.document?.layers.firstIndex(where: { $0.id == layer.id }) else { return }
        session.document?.layers[index].opacity = 0.5
        session.document?.layers[index].blendMode = .multiply
        session.document?.layers[index].isVisible = false
        let document = try export(session)
        #expect(document.width == 100 && document.height == 80)
        #expect(document.layers.map(\.name) == ["Red", "Blue"])
        let red = document.layers[0], blue = document.layers[1]
        #expect(red.bounds == CGRect(x: 10, y: 10, width: 40, height: 30))
        #expect(blue.bounds == CGRect(x: 60, y: 40, width: 20, height: 20))
        #expect(abs(blue.opacity - 0.5) < 0.01)
        #expect(blue.blendKey == "mul ")
        #expect(blue.isVisible == false)
        let image = try #require(red.image)
        let middle = try pixel(image, x: 20, y: 15)
        #expect(middle[0] > 240 && middle[1] < 10 && middle[3] > 240, "red: \(middle)")
    }

    @Test func groupsArriveAsPhotoshopFolders() throws {
        let session = try makeSession()
        let document = try #require(session.document)
        var group = ImageLayer(name: "Folder", blankSize: document.size)
        group.isGroup = true
        guard var layers = session.document?.layers, let blueIndex = layers.firstIndex(where: { $0.name == "Blue" }) else { return }
        layers.insert(group, at: blueIndex)
        layers[blueIndex + 1].parentID = group.id
        session.document?.layers = layers
        let parsed = try export(session)
        #expect(parsed.layers.map(\.name) == ["Red", "Blue", "Folder"])
        let folder = try #require(parsed.layers.first { $0.isGroup })
        #expect(folder.name == "Folder")
        #expect(parsed.layers.first { $0.name == "Blue" }?.parentID == folder.id)
    }

    @Test func masksTravelBesideTheirLayers() throws {
        let session = try makeSession()
        guard let index = session.document?.layers.firstIndex(where: { $0.name == "Red" }) else { return }
        let mask = try gray(1, width: 40, height: 30)
        session.document?.layers[index].mask = LayerMask(asset: ImportedImage(image: mask, thumbnail: mask, name: "Layer Mask"))
        let parsed = try export(session)
        let red = try #require(parsed.layers.first { $0.name == "Red" })
        let maskImage = try #require(red.mask)
        #expect(maskImage.width == 40 && maskImage.height == 30)
        #expect(try pixel(maskImage, x: 20, y: 15).first == 255)
    }

    /// Another reader opens the layered file as the merged picture, so apps that read no layers still see the canvas.
    @Test func anotherReaderShowsTheMergedPicture() throws {
        let session = try makeSession()
        let snapshot = try #require(session.projectSnapshot())
        let merged = try solid(0.5, 0.25, 0.75, width: 100, height: 80)
        let layers = try PSDLayerExport.layers(for: snapshot, width: 100, height: 80)
        let data = try PSDWriter.layered(width: 100, height: 80, layers: layers, merged: merged)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 100 && decoded.height == 80)
        let color = try pixel(decoded, x: 5, y: 5)
        #expect(abs(Int(color[0]) - 128) <= 2 && abs(Int(color[1]) - 64) <= 2 && abs(Int(color[2]) - 191) <= 2,
                "the merged picture: \(color)")
    }
}

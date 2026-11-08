import CoreGraphics
import Testing
@testable import Compositor

/// The files a layer export writes, for the Mac's Export Layers and the iOS app's share of the same layers.
@MainActor struct LayerExportPlanTests {
    private func image() throws -> CGImage {
        let context = try BrushRaster.context(width: 8, height: 8, mask: false)
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return try #require(context.makeImage())
    }

    /// A project of layers named `names`, bottom first as the document holds them, with the image every layer shows.
    private func session(_ names: [String]) throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 8, height: 8)
        // The layer a new document starts with, so the layers here are the only ones.
        session.document?.layers.removeAll()
        let image = try image()
        for name in names { session.insert(ImportedImage(image: image, thumbnail: image, name: name)) }
        return session
    }

    /// Top first as the panel lists them, each named for its layer, and two of the same name told apart with the upper
    /// keeping it.
    @Test func filesAreTopFirstAndToldApartByName() throws {
        let session = try session(["Gray", "Gray", "Blue"])
        let snapshot = try #require(session.projectSnapshot())
        let files = LayerExportPlan.files(in: snapshot, selected: Set(snapshot.manifest.layers.map(\.id)),
                                          active: session.activeLayerID)
        #expect(files.map(\.name) == ["Blue.png", "Gray.png", "Gray 2.png"])
        #expect(files.map(\.layerName) == ["Blue", "Gray", "Gray"])
    }

    /// A selection exports those layers and leaves the rest out.
    @Test func aSelectionChoosesTheLayers() throws {
        let session = try session(["Gray", "Blue"])
        let snapshot = try #require(session.projectSnapshot())
        let gray = try #require(snapshot.manifest.layers.first { $0.name == "Gray" }?.id)
        session.selectLayers([gray], primary: gray)
        #expect(LayerExportPlan.files(in: snapshot, selected: session.selectedLayerIDs, active: session.activeLayerID)
            .map(\.name) == ["Gray.png"])
    }
}

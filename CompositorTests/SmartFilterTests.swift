import AppKit
import Testing
@testable import Compositor

/// A smart filter is a filter layer clipped to one layer: it changes only that layer and stays editable.
@MainActor
struct SmartFilterTests {
    private func sessionWithAPixelLayer() throws -> (EditorSession, UUID) {
        let session = EditorSession()
        session.createDocument(width: 40, height: 40)
        let context = try BrushRaster.context(width: 20, height: 20, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Square"))
        return (session, try #require(session.activeLayerID))
    }

    @Test func addsAClippedFilterLayerInOneUndoStep() throws {
        let (session, target) = try sessionWithAPixelLayer()
        #expect(session.canAddSmartFilter)
        let count = session.history.undoCount
        session.addSmartFilter(.gaussianBlur)
        let layer = try #require(session.activeLayer)
        #expect(layer.adjustment?.kind == .gaussianBlur)
        #expect(layer.maskSourceID == target, "clipped to the layer it filters")
        #expect(session.history.undoCount == count + 1)
        #expect(session.history.undoName == "New Gaussian Blur Smart Filter")
        session.undo()
        #expect(session.document?.layers.count == 1)
    }

    @Test func layersWithoutPixelsCantTakeOne() throws {
        let session = EditorSession()
        session.createDocument(width: 20, height: 20)
        session.addAdjustment(.curves)
        #expect(!session.canAddSmartFilter)
        session.addGroup()
        #expect(!session.canAddSmartFilter)
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import Compositor

/// Each adjustment a layer can carry, applied on its own to a small image, as the canvas and QuickLook do.
@MainActor
@Suite(.serialized)
struct AdjustmentApplyTests {
    private func image(width: Int = 32, height: Int = 24) throws -> CGImage {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.setFillColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    private func run(_ adjustment: LayerAdjustment) throws -> CGImage {
        try adjustment.apply(try image(), region: CGRect(x: 0, y: 0, width: 32, height: 24),
                             scale: 1, document: CGSize(width: 32, height: 24))
    }

    @Test func vignetteApplies() throws {
        var adjustment = LayerAdjustment(kind: .vignette)
        adjustment.filterLayer.vignette = VignetteLayerSettings()
        adjustment.filterLayer.vignette?.amount = 80
        _ = try run(adjustment)
    }

    @Test func lensEffectsApplies() throws {
        var adjustment = LayerAdjustment(kind: .lensEffects)
        adjustment.filterLayer.lens = LensEffectSettings()
        adjustment.filterLayer.lens?.effect = .prism
        adjustment.filterLayer.lens?.prismFringe = 70
        _ = try run(adjustment)
    }

    @Test func tonalContrastApplies() throws {
        var adjustment = LayerAdjustment(kind: .tonalContrast)
        adjustment.filterLayer.tonal = TonalLayerSettings()
        adjustment.filterLayer.tonal?.amount = 100
        _ = try run(adjustment)
    }

    @Test func sharpenApplies() throws {
        var adjustment = LayerAdjustment(kind: .sharpen)
        adjustment.filterLayer.sharpen = SharpenLayerSettings()
        adjustment.filterLayer.sharpen?.amount = 200
        _ = try run(adjustment)
    }

    /// The same adjustments as a QuickLook preview sees them: the document drawn up to 1,024 px on its long side,
    /// which for a small canvas is a large scale.
    private func quickLook(_ kind: AdjustmentKind, _ change: (inout LayerAdjustment) -> Void) async throws {
        let session = EditorSession()
        session.createNewProject(width: 32, height: 24)
        let context = try BrushRaster.context(width: 32, height: 24, mask: false)
        context.setFillColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        let gray = try #require(context.makeImage())
        session.insert(ImportedImage(image: gray, thumbnail: gray, name: "Gray"))
        session.addAdjustment(kind)
        session.adjustmentEditingID = nil
        var adjustment = try #require(session.activeLayer?.adjustment)
        change(&adjustment)
        session.updateAdjustment(try #require(session.activeLayerID), value: adjustment)
        let snapshot = try #require(session.projectSnapshot())
        _ = await ImageExporter.shared.quickLookImages(snapshot)
    }

    @Test func renderWithVignette() async throws {
        let session = EditorSession()
        session.createNewProject(width: 200, height: 100)
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let gray = try #require(context.makeImage())
        session.insert(ImportedImage(image: gray, thumbnail: gray, name: "Gray"))
        session.addAdjustment(.vignette)
        session.adjustmentEditingID = nil
        var adjustment = try #require(session.activeLayer?.adjustment)
        adjustment.filterLayer.vignette = VignetteLayerSettings()
        adjustment.filterLayer.vignette?.amount = 80
        session.updateAdjustment(try #require(session.activeLayerID), value: adjustment)
        let snapshot = try #require(session.projectSnapshot())
        _ = try await ImageExporter.shared.render(snapshot, scale: 1)
    }

    @Test func plainQuickLook() async throws {
        let session = EditorSession()
        session.createNewProject(width: 32, height: 24)
        let context = try BrushRaster.context(width: 32, height: 24, mask: false)
        context.setFillColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        let gray = try #require(context.makeImage())
        session.insert(ImportedImage(image: gray, thumbnail: gray, name: "Gray"))
        let snapshot = try #require(session.projectSnapshot())
        _ = await ImageExporter.shared.quickLookImages(snapshot)
    }

    @Test func vignetteQuickLook() async throws {
        try await quickLook(.vignette) { $0.filterLayer.vignette = VignetteLayerSettings(); $0.filterLayer.vignette?.amount = 80 }
    }

    @Test func lensEffectsQuickLook() async throws {
        try await quickLook(.lensEffects) {
            $0.filterLayer.lens = LensEffectSettings(); $0.filterLayer.lens?.effect = .prism; $0.filterLayer.lens?.prismFringe = 70
        }
    }

    @Test func tonalContrastQuickLook() async throws {
        try await quickLook(.tonalContrast) { $0.filterLayer.tonal = TonalLayerSettings(); $0.filterLayer.tonal?.amount = 100 }
    }

    @Test func sharpenQuickLook() async throws {
        try await quickLook(.sharpen) { $0.filterLayer.sharpen = SharpenLayerSettings(); $0.filterLayer.sharpen?.amount = 200 }
    }
}

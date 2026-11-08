import AppKit
import Testing
@testable import Compositor

/// The Quick Selection brush selects what it paints over, growing to the edges of the color under it.
@MainActor
struct QuickSelectionTests {
    /// A 200×100 layer, red on the left half and blue on the right.
    private func makeSession() throws -> EditorSession {
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        let image = try #require(context.makeImage())
        let session = EditorSession()
        session.createDocument(width: 200, height: 100)
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Halves"))
        session.selectTool(.wand)
        session.wandMode = .quick
        session.brushSettings.diameter = 40
        return session
    }

    @Test func paintingSelectsTheColorUnderTheBrush() throws {
        let session = try makeSession()
        session.beginQuickSelection(at: CGPoint(x: 40, y: 50), mode: .replace)
        session.continueQuickSelection(at: CGPoint(x: 60, y: 50))
        session.finishQuickSelection()
        #expect(session.history.undoName == "Quick Selection")
        let selection = try #require(session.selection)
        #expect(selection.path.contains(CGPoint(x: 20, y: 50)), "the red half is selected")
        #expect(!selection.path.contains(CGPoint(x: 150, y: 50)), "the blue half is not")
    }

    /// One stroke paints one selection: painting on into another color adds it rather than replacing what came before.
    @Test func aStrokeAddsUpAcrossColors() throws {
        let session = try makeSession()
        session.beginQuickSelection(at: CGPoint(x: 40, y: 50), mode: .replace)
        session.continueQuickSelection(at: CGPoint(x: 160, y: 50))
        session.finishQuickSelection()
        let selection = try #require(session.selection)
        #expect(selection.path.contains(CGPoint(x: 20, y: 50)))
        #expect(selection.path.contains(CGPoint(x: 180, y: 50)))
    }

    @Test func theStrokeIsOneUndoStep() throws {
        let session = try makeSession()
        let count = session.history.undoCount
        session.beginQuickSelection(at: CGPoint(x: 40, y: 50), mode: .replace)
        for x in stride(from: 45.0, through: 90, by: 5) { session.continueQuickSelection(at: CGPoint(x: x, y: 50)) }
        session.finishQuickSelection()
        #expect(session.history.undoCount == count + 1)
        session.undo()
        #expect(session.selection == nil)
    }
}

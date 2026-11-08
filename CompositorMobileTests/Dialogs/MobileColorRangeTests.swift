import CoreGraphics
import Testing
import UIKit
@testable import Compositor

/// Select › Color Range on iPad: colors picked from the dialog's image select every pixel near them, and OK keeps the
/// selection as one step to undo.
@MainActor @Suite(.serialized) struct MobileColorRangeTests {
    /// A window with a 200 × 100 canvas, red on the left half and blue on the right.
    private func window() throws -> (EditorWindowController, EditorSession) {
        let window = EditorWindowController()
        window.loadViewIfNeeded()
        let session = try #require(window.activeTab?.session)
        session.createNewProject(width: 200, height: 100)
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Halves"))
        return (window, session)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<250 where !condition() { try await Task.sleep(for: .milliseconds(20)) }
    }

    /// A color picked from the image selects the pixels near it; OK keeps that selection as one step to undo.
    @Test func pickingAColorSelectsIt() async throws {
        let (window, session) = try window()
        let dialog = try #require(window.colorRangeDialog())
        dialog.loadViewIfNeeded()
        #expect(session.colorRange != nil)

        dialog.pick(at: CGPoint(x: 50, y: 50))
        try await eventually { session.colorRange?.preview != nil }
        #expect(session.document?.selection != nil)

        dialog.confirm()
        #expect(session.colorRange == nil)
        #expect(session.selection != nil)
        #expect(session.history.undoName == "Color Range")
    }

    /// Cancel puts back the selection there was and leaves no step behind.
    @Test func cancelPutsBackTheSelectionThereWas() async throws {
        let (window, session) = try window()
        let dialog = try #require(window.colorRangeDialog())
        dialog.loadViewIfNeeded()

        dialog.pick(at: CGPoint(x: 50, y: 50))
        try await eventually { session.colorRange?.preview != nil }
        dialog.cancel()

        #expect(session.colorRange == nil)
        #expect(session.selection == nil)
        #expect(session.history.undoName != "Color Range")
    }

    /// Its eyedroppers and Fuzziness ask the session to match again, as the Mac's panel does.
    @Test func fuzzinessMatchesAgain() async throws {
        let (window, session) = try window()
        let dialog = try #require(window.colorRangeDialog())
        dialog.loadViewIfNeeded()

        dialog.pick(at: CGPoint(x: 50, y: 50))
        try await eventually { session.colorRange?.preview != nil }
        dialog.setFuzziness(120)
        #expect(session.colorRange?.fuzziness == 120)
        try await eventually { session.colorRange?.preview != nil }
        #expect(session.document?.selection != nil)
    }
}

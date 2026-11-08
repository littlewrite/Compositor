import CoreGraphics
import Testing
import UIKit
@testable import Compositor

/// View › Grid Settings on iPad: the Mac's sheet as a dialog, changing the grid as it's edited, with Cancel putting back
/// what was there.
@MainActor @Suite(.serialized) struct MobileGridSettingsTests {
    private func window() throws -> (EditorWindowController, EditorSession) {
        let window = EditorWindowController()
        window.loadViewIfNeeded()
        let session = try #require(window.activeTab?.session)
        session.createNewProject(width: 200, height: 100)
        return (window, session)
    }

    /// The grid shows while the dialog is open, and each change shows on the session at once; Cancel puts back the grid
    /// and appearance there were, and whether the grid showed.
    @Test func editingShowsOnTheCanvasAndCancelPutsItBack() throws {
        let (window, session) = try window()
        let shown = session.showsGrid
        let original = (session.layoutGrid, session.gridAppearance)
        let dialog = try #require(window.gridSettingsDialog())
        dialog.loadViewIfNeeded()
        #expect(session.showsGrid)
        #expect(dialog.spacing == original.0.spacing && dialog.subdivisions == original.0.subdivisions)

        dialog.setSpacing(128)
        dialog.setSubdivisions(4)
        dialog.choosePreset(.magenta)
        dialog.chooseStyle(.dots)
        dialog.setOpacity(80)
        #expect(session.layoutGrid.spacing == 128 && session.layoutGrid.subdivisions == 4)
        #expect(session.gridAppearance.preset == .magenta && session.gridAppearance.style == .dots
                && session.gridAppearance.opacity == 80)

        dialog.cancel()
        #expect(session.layoutGrid == original.0)
        #expect(session.gridAppearance == original.1)
        #expect(session.showsGrid == shown)
    }

    /// OK keeps the changes, and leaves the grid showing as it was, so editing it doesn't turn it on.
    @Test func okKeepsTheChanges() throws {
        let (window, session) = try window()
        let shown = session.showsGrid
        let dialog = try #require(window.gridSettingsDialog())
        dialog.loadViewIfNeeded()

        dialog.setSpacing(96)
        dialog.setSubdivisions(6)
        dialog.choosePreset(.cyan)
        dialog.confirm()

        #expect(session.layoutGrid.spacing == 96 && session.layoutGrid.subdivisions == 6)
        #expect(session.gridAppearance.preset == .cyan)
        #expect(session.showsGrid == shown)
        #expect(session.history.undoName != "Grid")
    }

    /// More subdivisions than the pixels between gridlines can't be applied, as on the Mac, and the canvas keeps the
    /// last grid that could.
    @Test func subdivisionsNoMoreThanSpacing() throws {
        let (window, session) = try window()
        let dialog = try #require(window.gridSettingsDialog())
        dialog.loadViewIfNeeded()

        dialog.setSpacing(10)
        #expect(session.layoutGrid.spacing == 10)
        dialog.setSubdivisions(20)
        #expect(!dialog.confirmButton.isEnabled)
        #expect(session.layoutGrid.subdivisions == 8)
    }
}

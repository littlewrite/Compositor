import Foundation
import Testing
@testable import Compositor

/// Where a drop lands in a layer list, and the move it makes: the Mac's table and the iOS app's panel place layers
/// through these rules, so one table here covers both.
@MainActor
struct LayerListPlacementTests {
    private func flatSession() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 40, height: 30)
        for _ in 0..<3 { session.addBlankLayer() }
        return session
    }

    private func sessionWithFolder() -> EditorSession {
        let session = flatSession()
        let ids = Set(session.layerRows.prefix(2).map(\.layer.id))
        session.selectLayers(ids, primary: ids.first)
        session.groupSelectedLayers()
        return session
    }

    @Test func aRowDropLandsAboveIt() throws {
        let session = flatSession()
        let rows = session.layerRows
        try #require(rows.count >= 3)
        let moving = rows[2].layer.id, target = rows[0].layer.id

        #expect(LayerListPlacement.canPlace([moving], row: 0, intoFolder: false, rows: rows, in: session))
        #expect(LayerListPlacement.place([moving], row: 0, intoFolder: false, copying: false, in: session, rows: rows))

        let after = session.layerRows.map(\.layer.id)
        let targetIndex = try #require(after.firstIndex(of: target))
        #expect(after.firstIndex(of: moving) == targetIndex - 1, "directly above the row dropped on")
    }

    @Test func aDropOntoAFolderGoesInsideIt() throws {
        let session = sessionWithFolder()
        let rows = session.layerRows
        let folderRow = try #require(rows.firstIndex { $0.layer.isGroup == true })
        let folder = rows[folderRow].layer.id
        let inside = Set(session.layerRows.filter { $0.layer.parentID == folder }.map(\.layer.id))
        let moving = try #require(session.layerRows.first { !inside.contains($0.layer.id) && $0.layer.id != folder }).layer.id

        #expect(LayerListPlacement.place([moving], row: folderRow, intoFolder: true, copying: false, in: session, rows: rows))
        #expect(session.document?.layers.first { $0.id == moving }?.parentID == folder)
    }

    @Test func aDropPastTheLastRowGoesToTheBottom() throws {
        let session = flatSession()
        let rows = session.layerRows
        let moving = try #require(rows.first).layer.id

        #expect(LayerListPlacement.place([moving], row: rows.count, intoFolder: false, copying: false, in: session, rows: rows))
        #expect(session.layerRows.last?.layer.id == moving)
        #expect(session.document?.layers.first { $0.id == moving }?.parentID == nil)
    }

    @Test func layersDroppedTogetherKeepTheOrderTheyHad() throws {
        let session = flatSession()
        let rows = session.layerRows
        try #require(rows.count >= 3)
        let moving = [rows[1].layer.id, rows[2].layer.id], target = rows[0].layer.id

        #expect(LayerListPlacement.place(moving, row: 0, intoFolder: false, copying: false, in: session, rows: rows))
        let after = session.layerRows.map(\.layer.id)
        let targetIndex = try #require(after.firstIndex(of: target))
        #expect(Array(after[(targetIndex - 2)..<targetIndex]) == moving, "stacked in order, nearest the row dropped on last")
        #expect(session.selectedLayerIDs == Set(moving), "the layers that moved stay selected")
    }

    @Test func copyingDuplicatesTheLayersRatherThanMovingThem() throws {
        let session = flatSession()
        let rows = session.layerRows
        let before = try #require(session.document?.layers.count)
        let moving = try #require(rows.first).layer.id

        #expect(LayerListPlacement.place([moving], row: rows.count, intoFolder: false, copying: true, in: session, rows: rows))
        #expect(session.document?.layers.count == before + 1)
        #expect(session.document?.layers.contains { $0.id == moving } == true, "the layer copied stays where it was")
    }

    @Test func nothingToDropOrARowOutsideTheListIsRefused() throws {
        let session = flatSession()
        let rows = session.layerRows
        let id = try #require(rows.first?.layer.id)

        #expect(!LayerListPlacement.canPlace([], row: 0, intoFolder: false, rows: rows, in: session))
        #expect(!LayerListPlacement.canPlace([id], row: rows.count + 1, intoFolder: false, rows: rows, in: session))
        #expect(!LayerListPlacement.place([], row: 0, intoFolder: false, copying: false, in: session, rows: rows))
        #expect(!LayerListPlacement.place([id], row: rows.count + 1, intoFolder: false, copying: false, in: session, rows: rows))
    }
}

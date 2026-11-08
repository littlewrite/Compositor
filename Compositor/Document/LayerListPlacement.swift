import Foundation

/// Where a drop lands in a layer list, and moving the layers there. The Mac's table and the iOS app's collection view
/// share these rules; only their drag plumbing differs.
@MainActor enum LayerListPlacement {
    struct Destination {
        let parent: UUID?
        let above: UUID?
        let atBottom: Bool
    }

    /// Above the row, into the folder the row is, or at the bottom past the last row.
    static func destination(row: Int, intoFolder: Bool, rows: [LayerHierarchy.Entry]) -> Destination {
        if intoFolder, rows.indices.contains(row) {
            return Destination(parent: rows[row].layer.id, above: nil, atBottom: false)
        }
        guard rows.indices.contains(row) else {
            return Destination(parent: nil, above: nil, atBottom: true)
        }
        return Destination(parent: rows[row].layer.parentID, above: rows[row].layer.id, atBottom: false)
    }

    static func canPlace(_ ids: [UUID], row: Int, intoFolder: Bool, rows: [LayerHierarchy.Entry],
                         in session: EditorSession) -> Bool {
        guard session.canEditLayers, !ids.isEmpty, (0...rows.count).contains(row) else { return false }
        let destination = destination(row: row, intoFolder: intoFolder, rows: rows)
        return ids.allSatisfy { session.canPlaceLayer($0, in: destination.parent) }
    }

    @discardableResult
    static func place(_ ids: [UUID], row: Int, intoFolder: Bool, copying: Bool,
                      in session: EditorSession, rows: [LayerHierarchy.Entry]) -> Bool {
        guard (0...rows.count).contains(row), !ids.isEmpty else { return false }
        let destination = destination(row: row, intoFolder: intoFolder, rows: rows)
        // Dropped above a layer (or at the very bottom) the last one placed ends up nearest it, so they go in from the
        // top down; dropped into a folder each lands on top, so they go in from the bottom up.
        let order = intoFolder ? Array(ids.reversed()) : ids
        let name: String
        if copying { name = ids.count > 1 ? "Duplicate Layers" : "Duplicate Layer" }
        else { name = ids.count > 1 ? "Move Layers" : "Move Layer" }
        session.beginEdit(name)
        var placed = false
        for id in order {
            let done = copying
                ? session.duplicateLayer(id, in: destination.parent, above: destination.above, atBottom: destination.atBottom)
                : session.placeLayer(id, in: destination.parent, above: destination.above, atBottom: destination.atBottom)
            placed = done || placed
        }
        // The layers that moved stay selected, so they can be dragged on as a group.
        if placed, !copying { session.selectLayers(Set(ids), primary: ids.first) }
        session.endEdit()
        return placed
    }
}

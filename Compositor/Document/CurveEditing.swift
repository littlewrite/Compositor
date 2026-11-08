import Foundation

/// How a curve is shaped, in the editor's units, 0 to 255 on each axis: a press takes the nearest point within `reach`,
/// or else adds one there if there's room, and a dragged point keeps between its neighbors, while the end points move
/// only up and down. The Mac's curve editor and the iOS app's drag with these.
nonisolated enum CurveEditing {
    /// The point a press at (`x`, `y`) takes: an existing one within `reach`, or a new one, which goes into `points`.
    static func press(_ points: inout [CurvePoint], x: Double, y: Double, reach: Double = 14) -> Int? {
        if let index = points.indices.min(by: { hypot(points[$0].x - x, points[$0].y - y) < hypot(points[$1].x - x, points[$1].y - y) }),
           hypot(points[index].x - x, points[index].y - y) < reach {
            return index
        }
        guard points.count < 32, x > 1, x < 254, points.allSatisfy({ abs($0.x - x) > 1 }) else { return nil }
        points.append(CurvePoint(x: x, y: y))
        points.sort { $0.x < $1.x }
        return points.firstIndex { $0.x == x }
    }

    /// Point `index` dragged to (`x`, `y`).
    static func drag(_ points: inout [CurvePoint], index: Int, x: Double, y: Double) {
        guard points.indices.contains(index) else { return }
        points[index].y = y
        if index > 0, index < points.count - 1 { points[index].x = min(points[index + 1].x - 1, max(points[index - 1].x + 1, x)) }
    }
}

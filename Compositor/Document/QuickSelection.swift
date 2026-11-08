import CoreGraphics
import Foundation

/// A Quick Selection stroke in progress: the picture it reads, the mode the stroke combines with, and where its last
/// dab landed. The picture is taken once at the start, so the stroke reads what the canvas showed when it began.
@MainActor
final class QuickSelectionStroke {
    let documentID: UUID
    let mode: SelectionMode
    let sample: CGImage
    let radius: CGFloat
    var last: CGPoint
    /// The stroke's first dab brings in the mode held as it started; the ones after it add, as one stroke paints one
    /// selection.
    var isFirstDab = true

    init(documentID: UUID, mode: SelectionMode, sample: CGImage, radius: CGFloat, last: CGPoint) {
        self.documentID = documentID
        self.mode = mode
        self.sample = sample
        self.radius = radius
        self.last = last
    }
}

extension EditorSession {
    /// How far the Quick Selection brush looks, in document pixels: the brush tip, widened so a small tip still finds
    /// an edge.
    var quickSelectionRadius: CGFloat { max(8, brushSettings.diameter / 2) }

    /// Starts a Quick Selection stroke at `point`, in the mode that combines it with the selection already there.
    func beginQuickSelection(at point: CGPoint, mode: SelectionMode) {
        guard canEditSelection, !isProjectBusy, quickSelectionStroke == nil, let document,
              let sample = selectionSample(document, sampleAllLayers: wandSettings.sampleAllLayers) else { return }
        finishHeldDrags()
        beginEdit("Quick Selection")
        let stroke = QuickSelectionStroke(documentID: document.id, mode: mode, sample: sample,
                                          radius: quickSelectionRadius, last: point)
        quickSelectionStroke = stroke
        selectQuickly(at: point, stroke: stroke)
    }

    /// Adds the pixels under the brush at `point` to the stroke's selection, a dab apart from the last one.
    func continueQuickSelection(at point: CGPoint) {
        guard let stroke = quickSelectionStroke, document?.id == stroke.documentID else { return }
        let spacing = max(2, stroke.radius / 3)
        guard hypot(point.x - stroke.last.x, point.y - stroke.last.y) >= spacing else { return }
        stroke.last = point
        selectQuickly(at: point, stroke: stroke)
    }

    /// Ends the stroke, its dabs one undo step.
    func finishQuickSelection() {
        guard quickSelectionStroke != nil else { return }
        quickSelectionStroke = nil
        endEdit()
    }

    /// Drops the stroke in progress, taking back what its dabs selected.
    func cancelQuickSelection() {
        guard quickSelectionStroke != nil else { return }
        quickSelectionStroke = nil
        endEdit()
        undo()
    }

    /// The pixels near `point` like the one under it, as the Magic Wand finds them, applied in the stroke's mode.
    private func selectQuickly(at point: CGPoint, stroke: QuickSelectionStroke) {
        guard let document else { return }
        let reach = stroke.radius * 2
        let rect = CGRect(x: point.x - reach, y: point.y - reach, width: reach * 2, height: reach * 2)
            .intersection(CGRect(origin: .zero, size: document.size)).integral
        guard rect.width >= 2, rect.height >= 2, let crop = stroke.sample.cropping(to: rect) else { return }
        var settings = wandSettings
        settings.contiguous = true
        settings.sampleSize = .point
        guard let path = try? MagicWand.select(in: crop, at: CGPoint(x: point.x - rect.minX, y: point.y - rect.minY),
                                               settings: settings) else { return }
        var translation = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        guard let placed = path.copy(using: &translation) else { return }
        let mode: SelectionMode = stroke.isFirstDab ? stroke.mode : (stroke.mode == .subtract ? .subtract : .add)
        stroke.isFirstDab = false
        applySelection(placed, mode: mode, name: "Quick Selection")
    }
}

import CoreGraphics
import UIKit

/// View › Navigator: the Mac's minimap in the canvas's top right corner, shown from 300% zoom. The whole document in
/// small, with a box around what the canvas shows; touching or dragging in it moves the view there.
final class NavigatorView: MobileView {
    /// A setting of the person's, as the Mac's View menu keeps it.
    static let visibleKey = "navigator.visible"
    /// The zoom the navigator first shows at, as on the Mac.
    static let zoomShown: CGFloat = 3
    /// The most room the document takes, in points.
    static let largest = CGSize(width: 126, height: 90)
    /// Pixels on the picture's longer side: sharp on a Retina display.
    static let picturePixels = 300

    let session: EditorSession
    private var picture: CGImage?
    private var pictureKey: RenderKey?
    private var redraw: DispatchWorkItem?

    init(session: EditorSession) {
        self.session = session
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        accessibilityLabel = "Navigator".localized
        accessibilityHint = "Touch or drag to move the view".localized
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(moved(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The minimap's size for the document open: fitted inside `largest`, its proportions kept.
    var desiredSize: CGSize {
        guard let document = session.document, document.width > 0, document.height > 0 else { return CGSize(width: 1, height: 1) }
        let width = CGFloat(document.width), height = CGFloat(document.height)
        let scale = min(Self.largest.width / width, Self.largest.height / height)
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }

    override func updateProperties() {
        let document = session.document
        isHidden = !(UserDefaults.standard.bool(forKey: Self.visibleKey) && session.viewport.zoom >= Self.zoomShown && document != nil)
        if bounds.size != desiredSize { superview?.setNeedsLayout() }
        let key = RenderKey(document: document, revision: session.brushRevision)
        if key != pictureKey {
            pictureKey = key
            schedulePicture()
        }
        setNeedsDisplay()
    }

    /// Redraws the picture once edits settle, as the Mac's does: a stroke or a drag draws it once, afterwards.
    private func schedulePicture() {
        redraw?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.picture = self.session.navigatorImage(maxSide: Self.picturePixels)
            self.setNeedsDisplay()
        }
        redraw = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (picture == nil ? 0 : 0.25), execute: work)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let document = session.document else { return }
        let geometry = NavigatorGeometry(documentSize: document.size, box: bounds.size)
        let shape = UIBezierPath(roundedRect: bounds, cornerRadius: 4)
        context.saveGState()
        shape.addClip()
        UIColor(white: 0.11, alpha: 1).setFill()
        UIRectFill(bounds)
        if let picture {
            UIImage(cgImage: picture).draw(in: geometry.imageRect)
        }
        let shown = geometry.thumbnailRect(for: session.viewport.visibleDocumentRect(documentSize: document.size))
            .intersection(geometry.imageRect)
        if !shown.isNull, !shown.isEmpty {
            context.setStrokeColor(UIColor.tintColor.cgColor)
            context.setLineWidth(2.5)
            context.stroke(CGRect(x: shown.minX, y: shown.minY, width: max(3, shown.width), height: max(3, shown.height)))
        }
        context.restoreGState()
        UIColor.white.withAlphaComponent(0.25).setStroke()
        let border = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
        border.lineWidth = 1
        border.stroke()
    }

    @objc private func moved(_ gesture: UIPanGestureRecognizer) {
        guard let document = session.document else { return }
        let geometry = NavigatorGeometry(documentSize: document.size, box: bounds.size)
        session.viewport.centerView(on: geometry.documentPoint(for: gesture.location(in: self)), documentSize: document.size)
        setNeedsDisplay()
    }

    /// What the picture is drawn from: the layers rather than the whole document, so selecting and the like don't
    /// redraw it, as on the Mac.
    struct RenderKey: Equatable {
        let documentID: UUID?
        let size: CGSize
        let layers: [ImageLayer]
        let revision: Int

        init(document: CanvasDocument?, revision: Int) {
            documentID = document?.id
            size = document?.size ?? .zero
            layers = document?.layers ?? []
            self.revision = revision
        }
    }
}

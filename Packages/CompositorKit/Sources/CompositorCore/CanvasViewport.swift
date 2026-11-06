import CoreGraphics

/// The zoom and pan a canvas is shown at, and the screen/document conversion both sides need.
/// Kept in the core so the Mac and iPad canvases cannot drift apart in their arithmetic.
public struct CanvasViewport: Equatable, Sendable {
    public var documentSize: CGSize
    public var zoom: CGFloat
    public var pan: CGSize

    public init(documentSize: CGSize, zoom: CGFloat = 1, pan: CGSize = .zero) {
        self.documentSize = documentSize
        self.zoom = zoom
        self.pan = pan
    }

    /// The scale that shows the whole document in `window`, leaving a margin around it.
    public func fitScale(in window: CGSize, padding: CGFloat = 0.86) -> CGFloat {
        guard documentSize.width > 0, documentSize.height > 0,
              window.width > 0, window.height > 0 else { return 1 }
        return min(window.width / documentSize.width,
                   window.height / documentSize.height) * padding
    }

    /// The scale the document is drawn at right now: fit times zoom.
    public func scale(in window: CGSize, padding: CGFloat = 0.86) -> CGFloat {
        fitScale(in: window, padding: padding) * zoom
    }

    public func documentPoint(from screen: CGPoint, in window: CGSize, padding: CGFloat = 0.86) -> CGPoint {
        let scale = scale(in: window, padding: padding)
        return CGPoint(x: (screen.x - window.width / 2 - pan.width) / scale + documentSize.width / 2,
                       y: (screen.y - window.height / 2 - pan.height) / scale + documentSize.height / 2)
    }

    public func screenPoint(from document: CGPoint, in window: CGSize, padding: CGFloat = 0.86) -> CGPoint {
        let scale = scale(in: window, padding: padding)
        return CGPoint(x: (document.x - documentSize.width / 2) * scale + window.width / 2 + pan.width,
                       y: (document.y - documentSize.height / 2) * scale + window.height / 2 + pan.height)
    }

    public mutating func fit() {
        zoom = 1
        pan = .zero
    }

    public mutating func zoom(by factor: CGFloat, limits: ClosedRange<CGFloat> = 0.15...8) {
        zoom = min(limits.upperBound, max(limits.lowerBound, factor))
    }

    public func isInsideDocument(_ point: CGPoint) -> Bool {
        CGRect(origin: .zero, size: documentSize).contains(point)
    }
}

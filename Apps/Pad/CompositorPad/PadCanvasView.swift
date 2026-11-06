import SwiftUI
import UIKit
import CompositorCore

struct PadCanvasView: View {
    @ObservedObject var session: PadSession

    @State private var panStart: CGSize = .zero
    @State private var zoomBase: CGFloat = 1
    @State private var isPinching = false
    @State private var isPanning = false
    @State private var isDrawing = false
    @State private var isMoving = false
    @State private var moveOrigin: CGPoint = .zero
    @State private var gradientStart: CGPoint?
    @State private var gradientEnd: CGPoint?
    @State private var eyedropperPoint: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let scale = session.viewport.scale(in: geo.size)
            ZStack {
                Color(white: 0.07)
                Canvas { context, size in
                    var documentContext = context
                    let renderer = PadDocumentRenderer(
                        layers: session.layers,
                        strokes: session.strokes,
                        documentSize: session.documentSize,
                        levels: session.levels)
                    renderer.draw(in: &documentContext, size: size, scale: scale,
                                  pan: session.viewport.pan)
                    if let crop = session.cropRect {
                        // `draw` leaves the context in document space; the overlay is in screen space.
                        var overlayContext = context
                        drawCropOverlay(crop, in: &overlayContext, size: size)
                    }
                }
                zoomBadge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture(size: geo.size))
            .simultaneousGesture(magnifyGesture)
        }
    }

    private var zoomBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text("\(Int((session.viewport.zoom * 100).rounded()))%").monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: Input

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if session.tool.draws {
                    let point = session.viewport.documentPoint(from: value.location, in: size)
                    guard session.viewport.isInsideDocument(point) else { return }
                    if isDrawing {
                        session.extendStroke(to: point)
                    } else {
                        isDrawing = true
                        session.beginStroke(at: point)
                    }
                } else if session.tool == .move {
                    let scale = session.viewport.scale(in: size)
                    if !isMoving {
                        isMoving = true
                        moveOrigin = session.activeLayer?.transform.origin ?? .zero
                        session.beginEdit()
                    }
                    session.setActiveLayerOrigin(CGPoint(
                        x: moveOrigin.x + value.translation.width / scale,
                        y: moveOrigin.y + value.translation.height / scale))
                } else if session.tool == .gradient {
                    if gradientStart == nil {
                        gradientStart = session.viewport.documentPoint(
                            from: value.startLocation, in: size)
                    }
                    gradientEnd = session.viewport.documentPoint(
                        from: value.location, in: size)
                } else if session.tool == .crop {
                    let start = session.viewport.documentPoint(
                        from: value.startLocation, in: size)
                    let current = session.viewport.documentPoint(
                        from: value.location, in: size)
                    let rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                                      width: abs(current.x - start.x),
                                      height: abs(current.y - start.y))
                    let clamped = rect.intersection(
                        CGRect(origin: .zero, size: session.documentSize))
                    session.cropRect = clamped.isNull || clamped.width < 8 || clamped.height < 8
                        ? nil : clamped
                } else if session.tool == .eyedropper {
                    eyedropperPoint = session.viewport.documentPoint(
                        from: value.location, in: size)
                } else {
                    if !isPanning {
                        isPanning = true
                        panStart = session.viewport.pan
                    }
                    session.viewport.pan = CGSize(width: panStart.width + value.translation.width,
                                                  height: panStart.height + value.translation.height)
                }
            }
            .onEnded { _ in
                if isDrawing { session.endStroke() }
                isDrawing = false

                if isMoving { session.endEdit() }
                isMoving = false

                if let start = gradientStart {
                    let end = gradientEnd ?? start
                    if hypot(end.x - start.x, end.y - start.y) > 24 {
                        session.addGradientLayer(from: start, to: end,
                                                 color: session.brushColor)
                    }
                }
                gradientStart = nil
                gradientEnd = nil

                if let point = eyedropperPoint {
                    if #available(iOS 16.0, *),
                       let color = session.sampleColor(at: point) {
                        session.brushColor = color
                        session.platform.haptics.selectionChanged()
                    }
                    eyedropperPoint = nil
                }

                isPanning = false
                panStart = session.viewport.pan
            }
    }

    private func drawCropOverlay(_ crop: CGRect, in context: inout GraphicsContext, size: CGSize) {
        let topLeft = session.viewport.screenPoint(from: crop.origin, in: size)
        let bottomRight = session.viewport.screenPoint(
            from: CGPoint(x: crop.maxX, y: crop.maxY), in: size)
        let rect = CGRect(x: topLeft.x, y: topLeft.y,
                          width: bottomRight.x - topLeft.x,
                          height: bottomRight.y - topLeft.y)

        var dim = Path(CGRect(origin: .zero, size: size))
        dim.addRect(rect)
        context.fill(dim, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        context.stroke(Path(rect), with: .color(.white), lineWidth: 1.5)

        var thirds = Path()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let x = rect.minX + rect.width * fraction
            thirds.move(to: CGPoint(x: x, y: rect.minY))
            thirds.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * fraction
            thirds.move(to: CGPoint(x: rect.minX, y: y))
            thirds.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        context.stroke(thirds, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isPinching {
                    isPinching = true
                    zoomBase = session.viewport.zoom
                }
                session.viewport.zoom(by: zoomBase * value)
            }
            .onEnded { _ in isPinching = false }
    }

}

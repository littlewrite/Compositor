import SwiftUI
import UIKit

/// Draws the document into any `GraphicsContext`: the live canvas, and the export renderer.
struct PadDocumentRenderer {
    let layers: [PadLayer]
    let strokes: [PadStroke]
    let documentSize: CGSize
    let levels: PadLevels

    func draw(in context: inout GraphicsContext, size: CGSize, scale: CGFloat,
              pan: CGSize, drawsBorder: Bool = true) {
        context.translateBy(x: size.width / 2 + pan.width,
                            y: size.height / 2 + pan.height)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -documentSize.width / 2,
                            y: -documentSize.height / 2)

        let bounds = CGRect(origin: .zero, size: documentSize)
        context.fill(Path(bounds), with: .color(Color(white: 0.11)))
        context.drawLayer { documentContext in
            documentContext.clip(to: Path(bounds))
            apply(levels, to: &documentContext)
            drawLayers(context: &documentContext)
        }
        if drawsBorder {
            context.stroke(Path(bounds), with: .color(Color.white.opacity(0.12)),
                           lineWidth: 1 / scale)
        }
    }

    private func drawLayers(context: inout GraphicsContext) {
        for layer in layers where layer.isVisible {
            let transform = layer.transform
            let previousBlend = context.blendMode
            context.blendMode = blendMode(layer.blendMode)
            context.drawLayer { layerContext in
                layerContext.translateBy(x: transform.center.x, y: transform.center.y)
                layerContext.rotate(by: .degrees(transform.rotation))
                layerContext.opacity = layer.opacity
                apply(layer.adjustments, to: &layerContext)

                let rect = CGRect(x: -transform.size.width / 2, y: -transform.size.height / 2,
                                  width: transform.size.width, height: transform.size.height)
                draw(layer.kind, in: rect, context: &layerContext)

                for stroke in strokes where stroke.layerID == layer.id {
                    let blend: GraphicsContext.BlendMode = stroke.erases ? .destinationOut : .normal
                    layerContext.blendMode = blend
                    if stroke.hardness < 1 {
                        layerContext.drawLayer { softContext in
                            softContext.blendMode = blend
                            softContext.addFilter(.blur(
                                radius: stroke.width * (1 - stroke.hardness) * 0.5))
                            draw(stroke, origin: rect.origin, context: &softContext)
                        }
                    } else {
                        draw(stroke, origin: rect.origin, context: &layerContext)
                    }
                }
                layerContext.blendMode = .normal
            }
            context.blendMode = previousBlend
        }
    }

    private func blendMode(_ mode: LayerBlendMode) -> GraphicsContext.BlendMode {
        switch mode {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .difference: return .difference
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        }
    }

    private func apply(_ levels: PadLevels, to context: inout GraphicsContext) {
        guard !levels.isIdentity else { return }

        let black = min(max(levels.black, 0), 0.98)
        let white = max(black + 0.02, min(levels.white, 1))
        let brightness = (0.5 - (black + white) / 2) * 1.8
        var contrast = 1 / max(white - black, 0.2)
        contrast *= 1 + (1 - levels.gamma) * 0.35

        context.addFilter(.brightness(brightness))
        context.addFilter(.contrast(min(max(contrast, 0.2), 4)))
    }

    private func apply(_ adjustments: LayerAdjustments, to context: inout GraphicsContext) {
        guard !adjustments.isIdentity else { return }

        if adjustments.exposure != 0 {
            context.addFilter(.brightness(adjustments.exposure * 0.18))
        }
        if adjustments.contrast != 0 {
            context.addFilter(.contrast(1 + adjustments.contrast * 0.6))
        }
        if adjustments.saturation != 0 {
            context.addFilter(.saturation(1 + adjustments.saturation))
        }
        if adjustments.temperature != 0 {
            let amount = Float(adjustments.temperature)
            var matrix = ColorMatrix()
            matrix.r1 = 1 + amount * 0.16
            matrix.b3 = 1 - amount * 0.16
            matrix.r5 = amount * 0.02
            matrix.b5 = -amount * 0.02
            context.addFilter(.colorMatrix(matrix))
        }
        if adjustments.blur > 0 {
            context.addFilter(.blur(radius: adjustments.blur))
        }
        if adjustments.mono {
            context.addFilter(.saturation(0))
        }
        if adjustments.invert {
            var matrix = ColorMatrix()
            matrix.r1 = -1
            matrix.g2 = -1
            matrix.b3 = -1
            matrix.r5 = 1
            matrix.g5 = 1
            matrix.b5 = 1
            context.addFilter(.colorMatrix(matrix))
        }
    }

    private func draw(_ kind: PadLayer.Kind, in rect: CGRect, context: inout GraphicsContext) {
        switch kind {
        case .gradient(let top, let bottom):
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

        case .lights:
            for light in Self.lights {
                let center = CGPoint(x: rect.minX + rect.width * light.x,
                                     y: rect.minY + rect.height * light.y)
                let radius = rect.width * light.r
                let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                    width: radius * 2, height: radius * 2))
                context.fill(circle, with: .radialGradient(
                    Gradient(colors: [light.color.opacity(0.85), light.color.opacity(0)]),
                    center: center, startRadius: 0, endRadius: radius))
            }

        case .text(let string):
            let text = Text(string)
                .font(.system(size: rect.height * 0.58, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.94))
            context.draw(context.resolve(text), at: CGPoint(x: rect.midX, y: rect.midY))

        case .image(let image):
            context.draw(Image(uiImage: image), in: rect)

        case .blank:
            break
        }
    }

    private func draw(_ stroke: PadStroke, origin: CGPoint, context: inout GraphicsContext) {
        guard let first = stroke.points.first else { return }
        func placed(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x + origin.x, y: point.y + origin.y)
        }
        var path = Path()
        path.move(to: placed(first))
        for point in stroke.points.dropFirst() {
            path.addLine(to: placed(point))
        }
        if stroke.points.count == 1 {
            path.addLine(to: CGPoint(x: first.x + origin.x + 0.1, y: first.y + origin.y))
        }
        context.stroke(path, with: .color(stroke.color), style: StrokeStyle(
            lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
    }

    private static let lights: [(x: CGFloat, y: CGFloat, r: CGFloat, color: Color)] = [
        (0.18, 0.22, 0.28, Color(red: 1.0, green: 0.55, blue: 0.20)),
        (0.72, 0.18, 0.22, Color(red: 0.35, green: 0.60, blue: 1.00)),
        (0.82, 0.70, 0.30, Color(red: 1.00, green: 0.30, blue: 0.55)),
        (0.30, 0.75, 0.20, Color(red: 0.40, green: 0.95, blue: 0.70)),
    ]
}

struct PadExportView: View {
    let session: PadSession

    var body: some View {
        Canvas { context, size in
            var context = context
            let renderer = PadDocumentRenderer(
                layers: session.layers,
                strokes: session.strokes,
                documentSize: session.documentSize,
                levels: session.levels)
            renderer.draw(in: &context, size: size, scale: 1, pan: .zero, drawsBorder: false)
        }
        .frame(width: session.documentSize.width, height: session.documentSize.height)
    }
}

/// Renders a 1×1 view centered on one document pixel, so the eyedropper reads what the canvas shows.
struct PadSampleView: View {
    let session: PadSession
    let point: CGPoint

    var body: some View {
        Canvas { context, _ in
            var context = context
            let renderer = PadDocumentRenderer(
                layers: session.layers,
                strokes: session.strokes,
                documentSize: session.documentSize,
                levels: session.levels)
            let pan = CGSize(width: session.documentSize.width / 2 - point.x,
                             height: session.documentSize.height / 2 - point.y)
            renderer.draw(in: &context, size: CGSize(width: 1, height: 1),
                          scale: 1, pan: pan, drawsBorder: false)
        }
        .frame(width: 1, height: 1)
    }
}

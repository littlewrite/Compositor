import CoreGraphics
import Foundation

/// What a fill layer is filled with.
nonisolated enum FillContent: Equatable, Codable, Sendable {
    case solid(PaletteColor)
    case gradient(GradientFillSettings)

    var isSolid: Bool {
        if case .solid = self { return true }
        return false
    }
}

/// A fill layer, Solid Color or Gradient. Its pixels are an ordinary raster, so it masks, blends, filters and clips
/// like any layer; what fills it stays with the layer, so filling it again takes the new color rather than painting
/// over the old one.
nonisolated struct LayerFill: Equatable, @unchecked Sendable {
    var content: FillContent
    let image: CGImage
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.content == rhs.content && lhs.image === rhs.image }
    static func loaded(_ record: ProjectFillRecord?, image: CGImage?) -> LayerFill? {
        guard let content = record?.content, let image else { return nil }
        return LayerFill(content: content, image: image)
    }
}

extension ImageLayer {
    /// The fill this layer still is: nil once its pixels were edited some other way.
    var liveFill: LayerFill? {
        guard let fill, let image = asset?.image, image === fill.image else { return nil }
        return fill
    }
}

extension EditorSession {
    /// A Solid Color fill layer over the canvas, above the active layer, in the foreground color unless another is given.
    func addFillLayer(color: PaletteColor? = nil) {
        addFillLayer(content: .solid(color ?? foregroundColor), namePrefix: "Color Fill", editName: "Solid Color Fill")
    }

    /// A Gradient fill layer over the canvas, foreground to background from top to bottom unless another is given.
    func addGradientFillLayer(gradient: GradientFillSettings? = nil) {
        var settings = gradient ?? GradientFillSettings()
        if gradient == nil {
            settings.startColor = foregroundColor
            settings.endColor = backgroundColor
        }
        addFillLayer(content: .gradient(settings), namePrefix: "Gradient Fill", editName: "Gradient Fill")
    }

    private func addFillLayer(content: FillContent, namePrefix: String, editName: String) {
        guard canEditLayers, let document else { return }
        guard let image = Self.fillImage(content, width: document.width, height: document.height) else { return }
        let names = Set(document.layers.map(\.name))
        var number = 1
        while names.contains("\(namePrefix) \(number)") { number += 1 }
        addPixelLayer(image, at: .zero, name: "\(namePrefix) \(number)", editName: editName,
                      dropsSelection: false, fill: LayerFill(content: content, image: image))
    }

    /// Fills a Solid Color fill layer with a new color, one undo step; false when this layer is not one, or its pixels
    /// are no longer its fill.
    @discardableResult
    func recolorFillLayer(_ id: UUID, to color: PaletteColor) -> Bool {
        guard canEditLayers, let document, let index = document.layers.firstIndex(where: { $0.id == id }) else { return false }
        var layer = document.layers[index]
        guard let fill = layer.liveFill, fill.content != .solid(color),
              let previous = layer.asset,
              let image = Self.fillImage(.solid(color), width: previous.image.width, height: previous.image.height),
              let thumbnail = try? PixelInvert.thumbnail(of: image) else { return false }
        finishHeldDrags()
        beginEdit("Fill Color")
        layer.asset = ImportedImage(image: image, thumbnail: thumbnail, name: previous.name)
        layer.fill = LayerFill(content: .solid(color), image: image)
        self.document?.layers[index] = layer
        endEdit()
        return true
    }

    private static func fillImage(_ content: FillContent, width: Int, height: Int) -> CGImage? {
        guard let context = try? BrushRaster.context(width: width, height: height, mask: false) else { return nil }
        switch content {
        case .solid(let color):
            context.setFillColor(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .gradient(let settings):
            guard let gradient = settings.cgGradient else { return nil }
            let start = CGPoint(x: settings.start.x * CGFloat(width), y: settings.start.y * CGFloat(height))
            let end = CGPoint(x: settings.end.x * CGFloat(width), y: settings.end.y * CGFloat(height))
            let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            switch settings.shape {
            case .linear:
                context.drawLinearGradient(gradient, start: start, end: end, options: options)
            case .radial:
                let radius = hypot(end.x - start.x, end.y - start.y)
                context.drawRadialGradient(gradient, startCenter: start, startRadius: 0, endCenter: start, endRadius: radius,
                                           options: options)
            }
        }
        return context.makeImage()
    }
}

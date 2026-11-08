import Foundation
import CoreGraphics
import CoreImage

/// A line drawn around what the layer shows, outside its edge or inside it.
nonisolated struct StrokeEffect: Codable, Equatable, Sendable {
    /// Supported document-pixel width; preview work is bounded independently of this value.
    static let maxSize: CGFloat = 500
    var enabled: Bool? = nil // Missing in older projects means visible.
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 4
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 1
    var inside = false
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var isValid: Bool {
        size.isFinite && (0...StrokeEffect.maxSize).contains(size) && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// The layer's shape repeated behind it, offset and softened.
nonisolated struct ShadowEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    /// Where the light comes from, in degrees counterclockwise from the right, as Photoshop's dial is: 90 is from
    /// straight above, which drops the shadow straight down.
    var angle: CGFloat = 90
    var distance: CGFloat = 20
    var blur: CGFloat = 20
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 0.5
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    /// Where the shadow sits, in layer pixels (y grows downward, as the layer's own pixels do).
    var offset: CGSize {
        let radians = angle * .pi / 180
        // The shadow falls away from the light, and a layer's pixels count y downward.
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
    var isValid: Bool {
        [angle, distance, blur].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(distance) && (0...500).contains(blur)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A flat color over everything the layer shows.
nonisolated struct ColorOverlayEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 1
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var isValid: Bool {
        opacity.isFinite && (0...1).contains(opacity) && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A shadow cast inside the layer's own edges, as though it were cut out of what is behind it.
nonisolated struct InnerShadowEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var angle: CGFloat = 90
    var distance: CGFloat = 10
    var blur: CGFloat = 10
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 0.5
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    /// Where the shadow falls, in layer pixels (y grows downward).
    var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
    var isValid: Bool {
        [angle, distance, blur].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(distance) && (0...500).contains(blur)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A soft glow drawn omnidirectionally around the outside of what the layer shows.
nonisolated struct OuterGlowEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 20
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    var opacity: Double = 0.75
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var isValid: Bool {
        size.isFinite && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A glow cast inside the layer's own edges, emanating inward from its boundary.
nonisolated struct InnerGlowEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var size: CGFloat = 10
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    var opacity: Double = 0.75
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var isValid: Bool {
        size.isFinite && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A gradient painted over everything the layer shows, running across it at an angle.
nonisolated struct GradientOverlayEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    /// The direction the gradient runs, in degrees counterclockwise from the right, as the shadow effects' angle is.
    var angle: CGFloat = 90
    var opacity: Double = 1
    var reversed = false
    var startRed: CGFloat = 0
    var startGreen: CGFloat = 0
    var startBlue: CGFloat = 0
    var endRed: CGFloat = 1
    var endGreen: CGFloat = 1
    var endBlue: CGFloat = 1
    var startColor: PaletteColor { PaletteColor(red: startRed, green: startGreen, blue: startBlue) }
    var endColor: PaletteColor { PaletteColor(red: endRed, green: endGreen, blue: endBlue) }
    var isValid: Bool {
        angle.isFinite && (-360...360).contains(angle) && opacity.isFinite && (0...1).contains(opacity)
            && [startRed, startGreen, startBlue, endRed, endGreen, endBlue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A built-in tile that Pattern Overlay repeats across the layer.
nonisolated enum PatternPreset: String, CaseIterable, Codable, Sendable {
    case dots = "Dots"
    case checkerboard = "Checkerboard"
    case stripes = "Stripes"
    case grid = "Grid"
    case diamonds = "Diamonds"
    /// The pattern's name as menus show it, in the app's language; `rawValue` stays the project's.
    var displayName: String { rawValue.localized }

    /// The tile the overlay repeats, 64 pixels square, drawn in `ink` on a clear background.
    func tile(ink: PaletteColor) throws -> CGImage {
        let side = 64
        let context = try BrushRaster.context(width: side, height: side, mask: false)
        context.setFillColor(CGColor(srgbRed: ink.red, green: ink.green, blue: ink.blue, alpha: 1))
        switch self {
        case .dots:
            context.fillEllipse(in: CGRect(x: 20, y: 20, width: 24, height: 24))
        case .checkerboard:
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            context.fill(CGRect(x: 32, y: 32, width: 32, height: 32))
        case .stripes:
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 64))
        case .grid:
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 6))
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 64))
        case .diamonds:
            // A diamond in the middle and quarter diamonds at the corners, so the lattice continues across tiles.
            for center in [CGPoint(x: 32, y: 32), CGPoint(x: 0, y: 0), CGPoint(x: 64, y: 0),
                           CGPoint(x: 0, y: 64), CGPoint(x: 64, y: 64)] {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: center.x, y: center.y - 26))
                path.addLine(to: CGPoint(x: center.x + 26, y: center.y))
                path.addLine(to: CGPoint(x: center.x, y: center.y + 26))
                path.addLine(to: CGPoint(x: center.x - 26, y: center.y))
                path.closeSubpath()
                context.addPath(path)
            }
            context.fillPath()
        }
        guard let image = context.makeImage() else { throw ExportError.render }
        return image
    }
}

/// A pattern tiled over everything the layer shows, turned and scaled.
nonisolated struct PatternOverlayEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var pattern: PatternPreset = .dots
    /// The direction the tiles turn, in degrees clockwise from upright.
    var angle: CGFloat = 0
    /// The tile's size, as a percentage of its own 64 pixels.
    var scale: CGFloat = 100
    var opacity: Double = 1
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var isValid: Bool {
        angle.isFinite && (-360...360).contains(angle)
            && scale.isFinite && (1...1000).contains(scale)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}


/// A soft sheen inside the layer's edges, as light rakes across folded fabric: the layer's shape, moved and softened,
/// taken out of the layer itself.
nonisolated struct SatinEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var angle: CGFloat = 19
    var distance: CGFloat = 11
    var size: CGFloat = 14
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: Double = 0.5
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    /// Where the shape is moved, in layer pixels (y grows downward).
    var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * distance, height: sin(radians) * distance)
    }
    var isValid: Bool {
        [angle, distance, size].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(distance) && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// A lit edge: a highlight on the side facing the light and a shadow on the side away from it, both inside the layer.
/// Its color is the highlight's; the shadow is drawn in the shade the effect keeps beside it.
nonisolated struct BevelEffect: Codable, Equatable, Sendable {
    var enabled: Bool? = nil
    var isEnabled: Bool { enabled ?? true }
    var angle: CGFloat = 120
    var depth: CGFloat = 10
    var size: CGFloat = 6
    var opacity: Double = 0.75
    var red: CGFloat = 1
    var green: CGFloat = 1
    var blue: CGFloat = 1
    var shadowRed: CGFloat = 0
    var shadowGreen: CGFloat = 0
    var shadowBlue: CGFloat = 0
    var color: PaletteColor { PaletteColor(red: red, green: green, blue: blue) }
    var shadowColor: PaletteColor { PaletteColor(red: shadowRed, green: shadowGreen, blue: shadowBlue) }
    /// Where the shadow falls, in layer pixels (y grows downward); the highlight sits the other way.
    var offset: CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: -cos(radians) * depth, height: sin(radians) * depth)
    }
    var isValid: Bool {
        [angle, depth, size].allSatisfy(\.isFinite) && (-360...360).contains(angle)
            && (0...5000).contains(depth) && (0...500).contains(size)
            && opacity.isFinite && (0...1).contains(opacity)
            && [red, green, blue, shadowRed, shadowGreen, shadowBlue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

/// What a layer draws around itself. Kept with the layer, so it follows every edit and can be changed or removed
/// at any time; the pixels themselves are never touched.
nonisolated struct LayerEffects: Codable, Equatable, Sendable {
    var stroke: StrokeEffect? = nil
    var shadow: ShadowEffect? = nil
    var colorOverlay: ColorOverlayEffect? = nil
    var innerShadow: InnerShadowEffect? = nil
    var outerGlow: OuterGlowEffect? = nil
    var innerGlow: InnerGlowEffect? = nil
    var gradientOverlay: GradientOverlayEffect? = nil
    var patternOverlay: PatternOverlayEffect? = nil
    var satin: SatinEffect? = nil
    var bevel: BevelEffect? = nil
    var isEmpty: Bool {
        stroke == nil && shadow == nil && colorOverlay == nil && innerShadow == nil && outerGlow == nil && innerGlow == nil
            && gradientOverlay == nil && patternOverlay == nil && satin == nil && bevel == nil
    }
    /// Whether the GPU effects renderer draws every effect here; Gradient Overlay, Pattern Overlay, Satin and Bevel &
    /// Emboss are drawn on the CPU.
    var runsOnGPU: Bool { gradientOverlay == nil && patternOverlay == nil && satin == nil && bevel == nil }
    var isValid: Bool {
        (stroke?.isValid ?? true) && (shadow?.isValid ?? true)
            && (colorOverlay?.isValid ?? true) && (innerShadow?.isValid ?? true)
            && (outerGlow?.isValid ?? true) && (innerGlow?.isValid ?? true)
            && (gradientOverlay?.isValid ?? true) && (patternOverlay?.isValid ?? true)
            && (satin?.isValid ?? true) && (bevel?.isValid ?? true)
    }
    /// The effects for an image resampled by `factor`: every size, distance and blur in pixels scaled with it, held to
    /// the ranges `isValid` accepts.
    func scaled(by factor: CGFloat) -> LayerEffects {
        func scale(_ value: CGFloat?, upTo limit: CGFloat) -> CGFloat { min(limit, (value ?? 0) * factor) }
        var result = self
        result.stroke?.size = scale(stroke?.size, upTo: 500)
        result.shadow?.distance = scale(shadow?.distance, upTo: 5000)
        result.shadow?.blur = scale(shadow?.blur, upTo: 500)
        result.innerShadow?.distance = scale(innerShadow?.distance, upTo: 5000)
        result.innerShadow?.blur = scale(innerShadow?.blur, upTo: 500)
        result.outerGlow?.size = scale(outerGlow?.size, upTo: 500)
        result.innerGlow?.size = scale(innerGlow?.size, upTo: 500)
        result.satin?.distance = scale(satin?.distance, upTo: 5000)
        result.satin?.size = scale(satin?.size, upTo: 500)
        result.bevel?.depth = scale(bevel?.depth, upTo: 5000)
        result.bevel?.size = scale(bevel?.size, upTo: 500)
        return result
    }
    var kinds: [LayerEffectKind] { LayerEffectKind.allCases.filter { contains($0) } }
    func contains(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: return stroke != nil
        case .shadow: return shadow != nil
        case .colorOverlay: return colorOverlay != nil
        case .innerShadow: return innerShadow != nil
        case .outerGlow: return outerGlow != nil
        case .innerGlow: return innerGlow != nil
        case .gradientOverlay: return gradientOverlay != nil
        case .patternOverlay: return patternOverlay != nil
        case .satin: return satin != nil
        case .bevel: return bevel != nil
        }
    }
    func isEnabled(_ kind: LayerEffectKind) -> Bool {
        switch kind {
        case .stroke: return stroke?.isEnabled == true
        case .shadow: return shadow?.isEnabled == true
        case .colorOverlay: return colorOverlay?.isEnabled == true
        case .innerShadow: return innerShadow?.isEnabled == true
        case .outerGlow: return outerGlow?.isEnabled == true
        case .innerGlow: return innerGlow?.isEnabled == true
        case .gradientOverlay: return gradientOverlay?.isEnabled == true
        case .patternOverlay: return patternOverlay?.isEnabled == true
        case .satin: return satin?.isEnabled == true
        case .bevel: return bevel?.isEnabled == true
        }
    }
    /// The effect's own color, and a way to put a new one back.
    func color(_ kind: LayerEffectKind) -> PaletteColor? {
        switch kind {
        case .stroke: return stroke?.color
        case .shadow: return shadow?.color
        case .colorOverlay: return colorOverlay?.color
        case .innerShadow: return innerShadow?.color
        case .outerGlow: return outerGlow?.color
        case .innerGlow: return innerGlow?.color
        case .gradientOverlay: return gradientOverlay?.startColor
        case .patternOverlay: return patternOverlay?.color
        case .satin: return satin?.color
        case .bevel: return bevel?.color
        }
    }
    mutating func setColor(_ color: PaletteColor, for kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke?.red = color.red; stroke?.green = color.green; stroke?.blue = color.blue
        case .shadow: shadow?.red = color.red; shadow?.green = color.green; shadow?.blue = color.blue
        case .colorOverlay: colorOverlay?.red = color.red; colorOverlay?.green = color.green; colorOverlay?.blue = color.blue
        case .innerShadow: innerShadow?.red = color.red; innerShadow?.green = color.green; innerShadow?.blue = color.blue
        case .outerGlow: outerGlow?.red = color.red; outerGlow?.green = color.green; outerGlow?.blue = color.blue
        case .innerGlow: innerGlow?.red = color.red; innerGlow?.green = color.green; innerGlow?.blue = color.blue
        case .gradientOverlay:
            gradientOverlay?.startRed = color.red; gradientOverlay?.startGreen = color.green; gradientOverlay?.startBlue = color.blue
        case .patternOverlay: patternOverlay?.red = color.red; patternOverlay?.green = color.green; patternOverlay?.blue = color.blue
        case .satin: satin?.red = color.red; satin?.green = color.green; satin?.blue = color.blue
        case .bevel: bevel?.red = color.red; bevel?.green = color.green; bevel?.blue = color.blue
        }
    }
    /// A color of the effect's that the picker can edit: its own, or Gradient Overlay's second end (`end` 1).
    func color(_ kind: LayerEffectKind, end: Int) -> PaletteColor? {
        guard kind == .gradientOverlay, end == 1 else { return color(kind) }
        return gradientOverlay?.endColor
    }
    mutating func setColor(_ color: PaletteColor, for kind: LayerEffectKind, end: Int) {
        guard kind == .gradientOverlay, end == 1 else { setColor(color, for: kind); return }
        gradientOverlay?.endRed = color.red; gradientOverlay?.endGreen = color.green; gradientOverlay?.endBlue = color.blue
    }
    mutating func remove(_ kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke = nil
        case .shadow: shadow = nil
        case .colorOverlay: colorOverlay = nil
        case .innerShadow: innerShadow = nil
        case .outerGlow: outerGlow = nil
        case .innerGlow: innerGlow = nil
        case .gradientOverlay: gradientOverlay = nil
        case .patternOverlay: patternOverlay = nil
        case .satin: satin = nil
        case .bevel: bevel = nil
        }
    }
    mutating func setEnabled(_ enabled: Bool, for kind: LayerEffectKind) {
        switch kind {
        case .stroke: stroke?.enabled = enabled
        case .shadow: shadow?.enabled = enabled
        case .colorOverlay: colorOverlay?.enabled = enabled
        case .innerShadow: innerShadow?.enabled = enabled
        case .outerGlow: outerGlow?.enabled = enabled
        case .innerGlow: innerGlow?.enabled = enabled
        case .gradientOverlay: gradientOverlay?.enabled = enabled
        case .patternOverlay: patternOverlay?.enabled = enabled
        case .satin: satin?.enabled = enabled
        case .bevel: bevel?.enabled = enabled
        }
    }
    var visible: LayerEffects {
        LayerEffects(stroke: stroke?.isEnabled == true ? stroke : nil,
                     shadow: shadow?.isEnabled == true ? shadow : nil,
                     colorOverlay: colorOverlay?.isEnabled == true ? colorOverlay : nil,
                     innerShadow: innerShadow?.isEnabled == true ? innerShadow : nil,
                     outerGlow: outerGlow?.isEnabled == true ? outerGlow : nil,
                     innerGlow: innerGlow?.isEnabled == true ? innerGlow : nil,
                     gradientOverlay: gradientOverlay?.isEnabled == true ? gradientOverlay : nil,
                     patternOverlay: patternOverlay?.isEnabled == true ? patternOverlay : nil,
                     satin: satin?.isEnabled == true ? satin : nil,
                     bevel: bevel?.isEnabled == true ? bevel : nil)
    }
}

nonisolated enum LayerEffectKind: String, CaseIterable, Sendable {
    case stroke = "Stroke", shadow = "Drop Shadow", colorOverlay = "Color Overlay", innerShadow = "Inner Shadow", outerGlow = "Outer Glow", innerGlow = "Inner Glow"
    case gradientOverlay = "Gradient Overlay"
    case patternOverlay = "Pattern Overlay"
    case satin = "Satin", bevel = "Bevel & Emboss"

    /// The effect's name as menus and editors show it, in the app's language; `rawValue` stays the project's.
    var displayName: String { rawValue.localized }
}

struct LayerEffectSelection: Equatable {
    let layerID: UUID
    let kind: LayerEffectKind
}

extension EditorSession {
    var canEditEffects: Bool { canEditLayers && activeLayer?.isGroup == false && activeLayer?.asset != nil }
    var activeEffects: LayerEffects { activeLayer?.effects ?? LayerEffects() }
    var editingEffects: LayerEffects {
        document?.layers.first(where: { $0.id == effectsEditing?.layerID })?.effects ?? LayerEffects()
    }
    var selectedEffect: LayerEffectSelection? {
        guard let effectSelection, effectSelection.layerID == activeLayerID,
              activeEffects.contains(effectSelection.kind) else { return nil }
        return effectSelection
    }

    func addEffect(_ kind: LayerEffectKind) {
        guard canEditEffects, let id = activeLayerID else { return }
        if effectsEditing == LayerEffectSelection(layerID: id, kind: kind) { return }
        finishEffectsEditing(commit: false)
        let original = activeEffects
        var effects = original
        // A new stroke or overlay takes the background color: the foreground is usually what the layer is painted in.
        switch kind {
        case .stroke where effects.stroke == nil:
            var new = StrokeEffect()
            new.red = backgroundColor.red; new.green = backgroundColor.green; new.blue = backgroundColor.blue
            effects.stroke = new
        case .shadow where effects.shadow == nil:
            effects.shadow = ShadowEffect()
        case .colorOverlay where effects.colorOverlay == nil:
            var new = ColorOverlayEffect()
            new.red = backgroundColor.red; new.green = backgroundColor.green; new.blue = backgroundColor.blue
            effects.colorOverlay = new
        case .innerShadow where effects.innerShadow == nil:
            effects.innerShadow = InnerShadowEffect()
        case .outerGlow where effects.outerGlow == nil:
            effects.outerGlow = OuterGlowEffect()
        case .innerGlow where effects.innerGlow == nil:
            effects.innerGlow = InnerGlowEffect()
        case .gradientOverlay where effects.gradientOverlay == nil:
            var new = GradientOverlayEffect()
            new.startRed = backgroundColor.red; new.startGreen = backgroundColor.green; new.startBlue = backgroundColor.blue
            effects.gradientOverlay = new
        case .patternOverlay where effects.patternOverlay == nil:
            var new = PatternOverlayEffect()
            new.red = backgroundColor.red; new.green = backgroundColor.green; new.blue = backgroundColor.blue
            effects.patternOverlay = new
        case .satin where effects.satin == nil:
            effects.satin = SatinEffect()
        case .bevel where effects.bevel == nil:
            effects.bevel = BevelEffect()
        default: break
        }
        setEffects(effects, on: id, name: "Add " + kind.rawValue)
        selectEffect(kind, on: id, editing: true)
        effectsEditingOriginal = original
    }

    func selectEffect(_ kind: LayerEffectKind, on id: UUID, editing: Bool = false) {
        guard canEditLayers, document?.layers.first(where: { $0.id == id })?.effects?.contains(kind) == true else { return }
        let selection = LayerEffectSelection(layerID: id, kind: kind)
        if editing, effectsEditing != selection { finishEffectsEditing(commit: false) }
        selectLayer(id)
        selectedLayerIDs = [id]
        isMaskSelected = false
        effectSelection = selection
        if editing, effectsEditing != selection {
            if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: false) }
            effectsEditingOriginal = document?.layers.first(where: { $0.id == id })?.effects ?? LayerEffects()
            effectsEditing = selection
        }
    }

    /// Cancel restores only this panel's effect, preserving edits to other effects or layers.
    /// For a newly added effect the original value is absent, so Cancel removes it again.
    func finishEffectsEditing(commit: Bool) {
        guard let editing = effectsEditing else { return }
        // A drag still held is a step of its own, before Cancel's.
        finishEffectsChange()
        if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: commit) }
        if !commit, let original = effectsEditingOriginal,
           var effects = document?.layers.first(where: { $0.id == editing.layerID })?.effects {
            switch editing.kind {
            case .stroke: effects.stroke = original.stroke
            case .shadow: effects.shadow = original.shadow
            case .colorOverlay: effects.colorOverlay = original.colorOverlay
            case .innerShadow: effects.innerShadow = original.innerShadow
            case .outerGlow: effects.outerGlow = original.outerGlow
            case .innerGlow: effects.innerGlow = original.innerGlow
            case .gradientOverlay: effects.gradientOverlay = original.gradientOverlay
        case .patternOverlay: effects.patternOverlay = original.patternOverlay
            case .satin: effects.satin = original.satin
            case .bevel: effects.bevel = original.bevel
            }
            setEffects(effects, on: editing.layerID, name: "Cancel " + editing.kind.rawValue, fromPanel: true)
        }
        effectsEditing = nil
        effectsEditingOriginal = nil
        if selectedEffect == nil { effectSelection = nil }
    }

    /// `fromPanel`: the open panel's own edits and its Cancel, which text, a transform, a crop or a gradient waiting for
    /// Apply, started since, don't stop. An edit in the panel goes into the step of a drag held there; any other, the
    /// effect hidden or copied beside the panel say, ends the drag first, so it keeps a step of its own.
    /// `coalescing`: what the edit carries on, such as the color picker it came from, whose edits make one step (see
    /// `DocumentHistory.end`).
    func setEffects(_ effects: LayerEffects, on id: UUID? = nil, name: String = "Layer Effects", fromPanel: Bool = false,
                    coalescing group: AnyObject? = nil) {
        guard fromPanel ? canEditBesideCanvasEdits : canEditLayers, effects.isValid,
              let index = document?.layers.firstIndex(where: { $0.id == (id ?? activeLayerID) }),
              document?.layers[index].isGroup == false, document?.layers[index].asset != nil,
              document?.layers[index].effects != (effects.isEmpty ? nil : effects) else { return }
        if fromPanel { finishOpacityEdit() } else { finishHeldDrags() }
        beginEdit(name)
        document?.layers[index].effects = effects.isEmpty ? nil : effects
        endEdit(coalescing: group)
    }

    /// Panel edits stay bound to the layer that opened the panel, even if selection changes.
    func changeEffects(coalescing group: AnyObject? = nil, _ change: (inout LayerEffects) -> Void) {
        guard let editing = effectsEditing,
              let layer = document?.layers.first(where: { $0.id == editing.layerID }),
              layer.effects?.contains(editing.kind) == true else { return }
        var effects = layer.effects ?? LayerEffects()
        change(&effects)
        setEffects(effects, on: layer.id, name: String(format: "Edit %@".localized, editing.kind.displayName), fromPanel: true, coalescing: group)
    }

    /// A drag of a slider, or of its caption, in the effect's panel is one undo step, as Layer Opacity's is: what it
    /// sets goes into the step begun here, until it's let go. Like the panel's other edits, it goes through text, a
    /// transform, a crop or a gradient waiting for Apply, whose own steps end it first when they're applied.
    func beginEffectsChange() {
        guard canEditBesideCanvasEdits, !isChangingEffects, let editing = effectsEditing else { return }
        finishOpacityEdit()
        beginEdit(String(format: "Edit %@".localized, editing.kind.displayName))
        isChangingEffects = true
    }
    func finishEffectsChange() {
        guard isChangingEffects else { return }
        isChangingEffects = false
        endEdit()
    }
    /// Ends a drag still held, of Layer Opacity or in an effect's panel, so the edit about to be made, beside them or
    /// from the keyboard, is a step of its own rather than going into the drag's.
    func finishHeldDrags() {
        finishOpacityEdit()
        finishEffectsChange()
    }

    func canCopyEffect(_ kind: LayerEffectKind, from source: UUID, to target: UUID) -> Bool {
        guard canEditLayers, source != target,
              document?.layers.first(where: { $0.id == source })?.effects?.contains(kind) == true,
              let layer = document?.layers.first(where: { $0.id == target }),
              !layer.isGroup, layer.asset != nil else { return false }
        return true
    }

    func copyEffect(_ kind: LayerEffectKind, from source: UUID, to target: UUID) {
        guard canCopyEffect(kind, from: source, to: target),
              let original = document?.layers.first(where: { $0.id == source })?.effects else { return }
        // Close the destination's editor before replacing its effect so a later Cancel cannot undo the copy.
        if effectsEditing == LayerEffectSelection(layerID: target, kind: kind) {
            finishEffectsEditing(commit: true)
        }
        var effects = document?.layers.first(where: { $0.id == target })?.effects ?? LayerEffects()
        switch kind {
        case .stroke: effects.stroke = original.stroke
        case .shadow: effects.shadow = original.shadow
        case .colorOverlay: effects.colorOverlay = original.colorOverlay
        case .innerShadow: effects.innerShadow = original.innerShadow
        case .outerGlow: effects.outerGlow = original.outerGlow
        case .innerGlow: effects.innerGlow = original.innerGlow
        case .gradientOverlay: effects.gradientOverlay = original.gradientOverlay
        case .patternOverlay: effects.patternOverlay = original.patternOverlay
        case .satin: effects.satin = original.satin
        case .bevel: effects.bevel = original.bevel
        }
        setEffects(effects, on: target, name: "Copy " + kind.rawValue)
        selectEffect(kind, on: target)
    }

    func toggleEffect(_ kind: LayerEffectKind, on id: UUID) {
        guard var effects = document?.layers.first(where: { $0.id == id })?.effects else { return }
        let enabled = effects.isEnabled(kind)
        effects.setEnabled(!enabled, for: kind)
        setEffects(effects, on: id, name: (enabled ? "Hide " : "Show ") + kind.rawValue)
    }

    /// Ends the editing of an effect that's gone, undone or with its layer, and its color picker, so no panel stays
    /// open on nothing.
    func endEffectsEditingIfGone() {
        guard let editing = effectsEditing,
              document?.layers.first(where: { $0.id == editing.layerID })?.effects?.contains(editing.kind) != true else { return }
        finishEffectsChange()
        if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: false) }
        effectsEditing = nil
        effectsEditingOriginal = nil
    }

    func removeSelectedEffect() {
        guard let selectedEffect, canEditLayers,
              var effects = document?.layers.first(where: { $0.id == selectedEffect.layerID })?.effects else { return }
        finishEffectsChange()
        if effectsEditing == selectedEffect {
            if let picker = colorPicker, case .effect = picker.target { closeColorPicker(commit: false) }
            effectsEditing = nil
            effectsEditingOriginal = nil
        }
        effects.remove(selectedEffect.kind)
        setEffects(effects, on: selectedEffect.layerID, name: "Remove " + selectedEffect.kind.rawValue)
        effectSelection = nil
    }
}

/// Draws a layer's effects around its pixels. The result is the layer as it should appear — shadow behind, stroke
/// around, pixels on top — on a canvas grown by `inset` pixels on every side, so the caller places it by growing
/// the layer's transform in the same proportion.
nonisolated enum LayerEffectsRenderer {
    /// The last few layers drawn with effects, so the canvas doesn't rebuild them on every redraw.
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(image: CGImage, mask: CGImage?, effects: LayerEffects, result: CGImage, inset: CGFloat)] = []
        func result(image: CGImage, mask: CGImage?, effects: LayerEffects,
                    make: () throws -> (image: CGImage, inset: CGFloat)) throws -> (image: CGImage, inset: CGFloat) {
            lock.lock()
            let hit = entries.first { $0.image === image && $0.mask === mask && $0.effects == effects }
            lock.unlock()
            if let hit { return (hit.result, hit.inset) }
            let made = try make()
            lock.lock()
            let budget = 64 * 1024 * 1024
            let cost = made.image.bytesPerRow * made.image.height + image.bytesPerRow * image.height + (mask.map { $0.bytesPerRow * $0.height } ?? 0)
            if cost <= budget {
                entries.append((image, mask, effects, made.image, made.inset))
                while entries.count > 8 || entries.reduce(0, { $0 + $1.result.bytesPerRow * $1.result.height + $1.image.bytesPerRow * $1.image.height + ($1.mask.map { $0.bytesPerRow * $0.height } ?? 0) }) > budget {
                    entries.removeFirst()
                }
            }
            lock.unlock()
            return made
        }
    }
    private static let cache = Cache()

    /// `image` with `effects` around it, reusing the last result for the same pixels, mask and settings. Nil when
    /// there is nothing to draw or the effects can't be made, so the caller draws the layer as it is.
    static func cached(_ image: CGImage, mask: CGImage?, effects: LayerEffects?) -> (image: CGImage, inset: CGFloat)? {
        guard let effects = effects?.visible, !effects.isEmpty, effects.isValid else { return nil }
        return try? cache.result(image: image, mask: mask, effects: effects) {
            try render(image, mask: mask, effects: effects)
        }
    }

    /// The layer's transform grown by the margin its effects need, so the bigger image lands in the same place.
    static func placed(_ transform: LayerTransform, image: CGImage, inset: CGFloat) -> LayerTransform {
        var grown = transform
        let width = CGFloat(image.width), height = CGFloat(image.height)
        guard width > inset * 2, height > inset * 2 else { return transform }
        grown.size = CGSize(width: transform.size.width * width / (width - inset * 2),
                            height: transform.size.height * height / (height - inset * 2))
        grown.origin = CGPoint(x: transform.center.x - grown.size.width / 2, y: transform.center.y - grown.size.height / 2)
        return grown
    }

    static func margin(for effects: LayerEffects) -> CGFloat {
        let effects = effects.visible
        var margin: CGFloat = 0
        if let stroke = effects.stroke, !stroke.inside { margin = max(margin, stroke.size) }
        if let shadow = effects.shadow {
            margin = max(margin, shadow.distance + shadow.blur * 3)
        }
        if let glow = effects.outerGlow {
            margin = max(margin, glow.size * 3)
        }
        return ceil(margin) + 2
    }

    /// `image` with `effects` around it. `mask` (the layer's own mask, in its pixel grid) hides part of the layer
    /// before the effects are made, so they follow the shape that is actually shown, as in Photoshop.
    static func render(_ image: CGImage, mask: CGImage?, effects: LayerEffects) throws -> (image: CGImage, inset: CGFloat) {
        let effects = effects.visible
        guard effects.isValid else { throw ProjectError.invalid }
        let inset = margin(for: effects)
        let width = image.width + Int(inset) * 2, height = image.height + Int(inset) * 2
        guard width > 0, height > 0, width * height <= DocumentLimits.maxSurfacePixels else { throw ProjectError.tooLarge }
        let placed = CGRect(x: inset, y: inset, width: CGFloat(image.width), height: CGFloat(image.height))
        let full = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        // The layer as it is shown: its pixels through its mask.
        let shown = try masked(image, mask: mask)
        if let metal = MetalLayerEffects.shared, effects.runsOnGPU {
            // The pixels with room around them, then the stroke and shadow drawn on the GPU.
            let padded = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(shown, in: placed, mask: false, context: padded)
            if let room = padded.makeImage(), let built = try? metal.render(room, effects: effects) {
                return (built, inset)
            }
        }
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        if let shadow = effects.shadow, shadow.opacity > 0 {
            let alpha = try coverage(shown, in: placed.offsetBy(dx: shadow.offset.width, dy: shadow.offset.height),
                                     size: CGSize(width: width, height: height), blur: shadow.blur)
            fill(shadow.color, alpha: shadow.opacity, coverage: alpha, in: full, context: context)
        }
        if let glow = effects.outerGlow, glow.opacity > 0 {
            let alpha = try outerGlowCoverage(shown, placed: placed, size: CGSize(width: width, height: height), glow: glow)
            fill(glow.color, alpha: glow.opacity, coverage: alpha, in: full, context: context)
        }
        // An outside stroke sits behind the layer's own pixels; an inside one is drawn over them, or the pixels
        // would simply cover it.
        let stroke = effects.stroke.flatMap { $0.size > 0 && $0.opacity > 0 ? $0 : nil }
        func drawStroke(_ stroke: StrokeEffect) throws {
            let alpha = try strokeCoverage(shown, placed: placed, size: CGSize(width: width, height: height), stroke: stroke)
            fill(stroke.color, alpha: stroke.opacity, coverage: alpha, in: full, context: context)
        }
        if let stroke, !stroke.inside { try drawStroke(stroke) }
        // Source-over preserves effects beneath transparent pixels. BrushRaster.draw uses .copy,
        // which would erase the stroke/shadow everywhere inside the source's rectangular bounds.
        // The layer's own pixels, recolored by a color overlay, then an inner glow and an inner shadow, each keeping
        // the pixels' alpha as Photoshop's do, so a translucent pixel takes them fully and the effects beneath stay
        // untinted.
        let layer = try BrushRaster.context(width: width, height: height, mask: false)
        BrushRaster.draw(shown, in: placed, mask: false, context: layer)
        if let overlay = effects.colorOverlay, overlay.isEnabled, overlay.opacity > 0 {
            recolor(layer, overlay.color, alpha: overlay.opacity, amount: nil, in: full)
        }
        if let gradientOverlay = effects.gradientOverlay, gradientOverlay.isEnabled, gradientOverlay.opacity > 0 {
            drawGradient(gradientOverlay, bounds: placed, context: layer)
        }
        if let patternOverlay = effects.patternOverlay, patternOverlay.isEnabled, patternOverlay.opacity > 0 {
            drawPattern(patternOverlay, bounds: placed, context: layer)
        }
        if let innerGlow = effects.innerGlow, innerGlow.isEnabled, innerGlow.opacity > 0,
           let insideGlow = try? innerGlowCoverage(shown, placed: placed, size: CGSize(width: width, height: height), glow: innerGlow) {
            recolor(layer, innerGlow.color, alpha: innerGlow.opacity, amount: insideGlow, in: full)
        }
        if let inner = effects.innerShadow, inner.isEnabled, inner.opacity > 0,
           let inside = try? innerCoverage(shown, placed: placed, size: CGSize(width: width, height: height), shadow: inner) {
            recolor(layer, inner.color, alpha: inner.opacity, amount: inside, in: full)
        }
        if let bevel = effects.bevel, bevel.isEnabled, bevel.opacity > 0,
           let shade = try? bevelCoverage(shown, placed: placed, size: CGSize(width: width, height: height), bevel: bevel, toward: false) {
            recolor(layer, bevel.shadowColor, alpha: bevel.opacity, amount: shade, in: full)
            if let light = try? bevelCoverage(shown, placed: placed, size: CGSize(width: width, height: height), bevel: bevel, toward: true) {
                recolor(layer, bevel.color, alpha: bevel.opacity, amount: light, in: full)
            }
        }
        if let satin = effects.satin, satin.isEnabled, satin.opacity > 0,
           let sheen = try? satinCoverage(shown, placed: placed, size: CGSize(width: width, height: height), satin: satin) {
            recolor(layer, satin.color, alpha: satin.opacity, amount: sheen, in: full)
        }
        guard let styled = layer.makeImage() else { throw ExportError.render }
        context.saveGState()
        context.translateBy(x: 0, y: full.height)
        context.scaleBy(x: 1, y: -1)
        context.setBlendMode(.normal)
        context.draw(styled, in: full)
        context.restoreGState()
        if let stroke, stroke.inside { try drawStroke(stroke) }
        guard let result = context.makeImage() else { throw ExportError.render }
        return (result, inset)
    }

    /// How strongly an inner glow falls on each pixel: strongest at the layer's edges, fading inward. It's the
    /// strength before the layer's own alpha, which the glow keeps as it recolors the pixels (see `recolor`).
    static func innerGlowCoverage(_ image: CGImage, placed: CGRect, size: CGSize, glow: InnerGlowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let blurred = try coverage(image, in: placed, size: size, blur: glow.size)
        let inside = try GuidedMatte.levels(of: blurred, width: width, height: height).map { max(0, min(1, 1 - $0)) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// The layer's pixels with its mask applied, or the pixels as they are when it has none.
    private static func masked(_ image: CGImage, mask: CGImage?) throws -> CGImage {
        guard let mask else { return image }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let context = try BrushRaster.context(width: image.width, height: image.height, mask: false)
        // Draw the source and its grayscale mask in the same image coordinate system.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.clip(to: bounds, mask: mask)
        context.draw(image, in: bounds)
        guard let result = context.makeImage() else { throw ExportError.render }
        return result
    }

    /// Moves the pixels' color toward `color` by `alpha`, scaled by `amount` where given, keeping their alpha:
    /// source-atop, so a half-transparent pixel takes the color fully.
    static func recolor(_ context: CGContext, _ color: PaletteColor, alpha: Double, amount: CGImage?, in rect: CGRect) {
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        if let amount { fill(color, alpha: alpha, coverage: amount, in: rect, context: context) }
        else {
            context.setFillColor(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: CGFloat(alpha)))
            context.fill(rect)
        }
        context.restoreGState()
    }

    /// A gradient overlay painted over the layer's pixels, within their alpha, across the layer's box: the angle turns
    /// clockwise from left to right, so 90 runs from top to bottom.
    static func drawGradient(_ gradient: GradientOverlayEffect, bounds: CGRect, context: CGContext) {
        let radians = gradient.angle * .pi / 180
        // The gradient spans the layer's box along its direction, so its colors land on the edges the angle points at.
        let reach = (abs(cos(radians)) * bounds.width + abs(sin(radians)) * bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // This layer buffer counts y downward, as the document does, so the angle is used as it is.
        let direction = CGPoint(x: cos(radians) * reach, y: sin(radians) * reach)
        var from = center, to = center
        if gradient.reversed {
            from = CGPoint(x: center.x - direction.x, y: center.y + direction.y)
            to = CGPoint(x: center.x + direction.x, y: center.y - direction.y)
        } else {
            from = CGPoint(x: center.x - direction.x, y: center.y - direction.y)
            to = CGPoint(x: center.x + direction.x, y: center.y + direction.y)
        }
        let colors = [gradient.startColor, gradient.endColor].map {
            CGColor(srgbRed: $0.red, green: $0.green, blue: $0.blue, alpha: 1)
        }
        guard let gradientFill = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray,
                                            locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        context.setAlpha(CGFloat(gradient.opacity))
        context.drawLinearGradient(gradientFill, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    /// A pattern tiled over the layer's pixels, within their alpha, turned and scaled about the layer's box.
    static func drawPattern(_ pattern: PatternOverlayEffect, bounds: CGRect, context: CGContext) {
        guard pattern.isValid, let tile = try? pattern.pattern.tile(ink: pattern.color) else { return }
        let period = CGFloat(tile.width) * pattern.scale / 100
        guard period >= 2 else { return }
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        context.setAlpha(CGFloat(pattern.opacity))
        context.clip(to: bounds)
        // This layer buffer counts y downward, so a positive turn runs clockwise on screen.
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: pattern.angle * .pi / 180)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        // Enough tiles, around the box's middle, to cover it once turned.
        let reach = hypot(bounds.width, bounds.height) / 2 + period
        let count = Int(ceil(reach * 2 / period)) + 1
        let start = CGPoint(x: bounds.midX - reach, y: bounds.midY - reach)
        for row in 0..<count {
            for column in 0..<count {
                context.draw(tile, in: CGRect(x: start.x + CGFloat(column) * period, y: start.y + CGFloat(row) * period,
                                              width: period, height: period))
            }
        }
        context.restoreGState()
    }

    /// A shadow's coverage for one piece of a layer: its shape, moved and softened.
    static func shadowCoverage(_ pixels: CGImage, in size: CGSize, offset: CGSize, blur: CGFloat) throws -> CGImage {
        let placed = CGRect(origin: .zero, size: CGSize(width: pixels.width, height: pixels.height))
        return try coverage(pixels, in: placed.offsetBy(dx: offset.width, dy: offset.height), size: size, blur: blur)
    }

    /// How strongly an inner shadow falls on each pixel: what lies outside the layer, moved and softened. Like
    /// `innerGlowCoverage`, it's the strength before the layer's own alpha.
    static func innerCoverage(_ image: CGImage, placed: CGRect, size: CGSize, shadow: InnerShadowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let moved = try coverage(image, in: placed.offsetBy(dx: shadow.offset.width, dy: shadow.offset.height),
                                 size: size, blur: shadow.blur)
        let inside = try GuidedMatte.levels(of: moved, width: width, height: height).map { max(0, min(1, 1 - $0)) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// How strongly satin falls on each pixel: the layer's shape, moved and softened, taken out of the layer, so the
    /// sheen gathers along the edge farthest from where the shape went. Like `innerCoverage`, it's the strength before
    /// the layer's own alpha.
    static func satinCoverage(_ image: CGImage, placed: CGRect, size: CGSize, satin: SatinEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let moved = try coverage(image, in: placed.offsetBy(dx: satin.offset.width, dy: satin.offset.height),
                                 size: size, blur: satin.size)
        let levels = try GuidedMatte.levels(of: moved, width: width, height: height)
        let shape = try GuidedMatte.levels(of: coverage(image, in: placed, size: size, blur: 0), width: width, height: height)
        var inside = levels
        for i in inside.indices { inside[i] = max(0, min(1, (1 - levels[i]) * shape[i])) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// A bevel's coverage on the side the light comes from (`toward` true) or the side away from it: the layer's edge,
    /// moved toward the light for the highlight and away from it for the shadow, softened, and taken out of the layer.
    /// Like `innerCoverage`, it's the strength before the layer's own alpha.
    static func bevelCoverage(_ image: CGImage, placed: CGRect, size: CGSize, bevel: BevelEffect,
                              toward: Bool) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        // The shadow falls away from the light, so the lit side is the shape moved the way the shadow goes.
        let reach = toward ? bevel.offset : CGSize(width: -bevel.offset.width, height: -bevel.offset.height)
        let moved = try coverage(image, in: placed.offsetBy(dx: reach.width, dy: reach.height),
                                 size: size, blur: bevel.size)
        let levels = try GuidedMatte.levels(of: moved, width: width, height: height)
        let shape = try GuidedMatte.levels(of: coverage(image, in: placed, size: size, blur: 0), width: width, height: height)
        var inside = levels
        for i in inside.indices { inside[i] = max(0, min(1, (1 - levels[i]) * shape[i])) }
        return try GuidedMatte.image(inside, width: width, height: height)
    }

    /// An outer glow's coverage: the layer's shape softened omnidirectionally, with the shape interior excluded.
    static func outerGlowCoverage(_ image: CGImage, placed: CGRect, size: CGSize, glow: OuterGlowEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let shape = try coverage(image, in: placed, size: size, blur: 0)
        let soft = try coverage(image, in: placed, size: size, blur: glow.size)
        var levels = try GuidedMatte.levels(of: soft, width: width, height: height)
        let mask = try GuidedMatte.levels(of: shape, width: width, height: height)
        for i in levels.indices {
            levels[i] = max(0, min(1, levels[i] * (1 - mask[i])))
        }
        return try GuidedMatte.image(levels, width: width, height: height)
    }

    /// A stroke's ring for one piece of a layer.
    static func ringCoverage(_ pixels: CGImage, in size: CGSize, stroke: StrokeEffect) throws -> CGImage {
        try strokeCoverage(pixels, placed: CGRect(origin: .zero, size: CGSize(width: pixels.width, height: pixels.height)),
                           size: size, stroke: stroke)
    }

    /// The shape's own alpha, placed in a bigger canvas and optionally softened: gray, white where the layer is.
    static func coverage(_ image: CGImage, in rect: CGRect, size: CGSize, blur: CGFloat) throws -> CGImage {
        let context = try BrushRaster.context(width: Int(size.width), height: Int(size.height), mask: true)
        BrushRaster.draw(image, in: rect, mask: true, context: context)
        guard let sharp = context.makeImage() else { throw ExportError.render }
        guard blur > 0 else { return sharp }
        let extent = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let soft = CIImage(cgImage: sharp).clampedToExtent().applyingGaussianBlur(sigma: blur / 2).cropped(to: extent)
        return try PixelAdjust.render(soft, width: Int(size.width), height: Int(size.height), isMask: true)
    }

    /// Where a stroke lands: the shape grown (or shrunk) by its size, less the shape itself. A square reach, not a
    /// round one — a round one eats into the corners of a rectangle, which reads as a wobbly edge.
    static func strokeCoverage(_ image: CGImage, placed: CGRect, size: CGSize, stroke: StrokeEffect) throws -> CGImage {
        let width = Int(size.width), height = Int(size.height)
        let shape = try coverage(image, in: placed, size: size, blur: 0)
        var levels = try GuidedMatte.levels(of: shape, width: width, height: height)
        let reach = max(1, Int(stroke.size.rounded()))
        let moved = extreme(levels, width: width, height: height, reach: reach, smallest: stroke.inside)
        // The ring between the two shapes.
        for i in levels.indices {
            levels[i] = stroke.inside ? max(0, levels[i] - moved[i]) : max(0, moved[i] - levels[i])
        }
        return try GuidedMatte.image(levels, width: width, height: height)
    }

    /// The largest (or smallest) value within `reach` on each side: two sliding-window passes, so the cost doesn't
    /// grow with the reach. Core Image's own morphology filters stall on a wide stroke.
    static func extreme(_ source: [Float], width: Int, height: Int, reach: Int, smallest: Bool) -> [Float] {
        guard width > 0, height > 0, source.count == width * height else { return [] }
        let radius = max(0, reach)
        var pass = [Float](repeating: 0, count: source.count)
        var result = [Float](repeating: 0, count: source.count)
        // Each index enters and leaves the deque at most once. A head index avoids Array.removeFirst's
        // shifting cost; one reusable buffer avoids allocating a queue and values array for every line.
        var queue = [Int](repeating: 0, count: max(width, height))
        func sweep(_ input: UnsafeBufferPointer<Float>, _ output: UnsafeMutableBufferPointer<Float>,
                   lines: Int, count: Int, lineStep: Int, elementStep: Int) {
            for line in 0..<lines {
                let base = line * lineStep
                var head = 0, tail = 0, next = 0
                for center in 0..<count {
                    while next <= min(count - 1, center + radius) {
                        let value = input[base + next * elementStep]
                        while tail > head {
                            let previous = input[base + queue[tail - 1] * elementStep]
                            if smallest ? previous < value : previous > value { break }
                            tail -= 1
                        }
                        queue[tail] = next
                        tail += 1
                        next += 1
                    }
                    while head < tail, queue[head] < center - radius { head += 1 }
                    let outside = center < radius || center + radius >= count
                    output[base + center * elementStep] = smallest && outside ? 0 : input[base + queue[head] * elementStep]
                }
            }
        }
        source.withUnsafeBufferPointer { input in
            pass.withUnsafeMutableBufferPointer { output in
                sweep(input, output, lines: height, count: width, lineStep: width, elementStep: 1)
            }
        }
        pass.withUnsafeBufferPointer { input in
            result.withUnsafeMutableBufferPointer { output in
                sweep(input, output, lines: width, count: height, lineStep: 1, elementStep: width)
            }
        }
        return result
    }

    static func fill(_ color: PaletteColor, alpha: Double, coverage: CGImage, in rect: CGRect, context: CGContext) {
        // Coverage is a CGImage: use the same local image flip as the source, so asymmetric marks
        // and their effects line up instead of mirroring the coverage vertically.
        BrushRaster.fill(CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1),
                         coverage: coverage, in: rect, alpha: CGFloat(alpha), context: context)
    }
}

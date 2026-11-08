import CoreGraphics
import Foundation
import CoreImage
import Observation

/// Filters from the Filter menu. Each runs on the active image layer, inside the selection if
/// there is one, with a live preview and one undo step on OK.
nonisolated enum FilterKind: String, CaseIterable, Sendable {
    case gaussianBlur = "Gaussian Blur"
    case motionBlur = "Motion Blur"
    case progressiveBlur = "Progressive Blur"
    case sharpen = "Sharpen"
    case reduceNoise = "Reduce Noise"
    case addNoise = "Add Noise"
    case vignette = "Vignette"
    case bloomGlow = "Bloom / Glow"
    case dither = "Dither"
    case scanlines = "Scanlines"
    case rgbSplit = "RGB Split"
    case lensEffects = "Lens Effects"
    case tonalContrast = "Tonal Contrast"
    case volumetricLight = "Volumetric Light"
    case rimLight = "Rim Light"
    case lensCorrection = "Lens Correction"
    case wave = "Wave"
    case ripple = "Ripple"
    case tiltShiftBlur = "Tilt-Shift Blur"
    case irisBlur = "Iris Blur"
    case boxBlur = "Box Blur"
    case zoomBlur = "Zoom Blur"
    case bokehBlur = "Bokeh Blur"
    case median = "Median"
    case photoEffect = "Photo Effect"
    case mosaic = "Mosaic"
    case crystallize = "Crystallize"
    case colorHalftone = "Color Halftone"
    case pointillize = "Pointillize"
    case hexagonalPixelate = "Hexagonal Pixelate"
    case twirl = "Twirl"
    case pinch = "Pinch"
    case spherize = "Spherize"
    case vortex = "Vortex"
    case hole = "Hole"
    case circleSplash = "Circle Splash"
    case torusLens = "Torus Lens"
    case gloom = "Gloom"
    case kaleidoscope = "Kaleidoscope"
    case findEdges = "Find Edges"
    case comic = "Comic"
    case lineScreen = "Line Screen"
    case circularScreen = "Circular Screen"
    case hatchedScreen = "Hatched Screen"
    case glass = "Glass"
    case glassLozenge = "Glass Lozenge"
    case triangleKaleidoscope = "Triangle Kaleidoscope"
    case falseColor = "False Color"
    case monochrome = "Monochrome"
    case discBlur = "Disc Blur"
    case lensFlare = "Lens Flare"
    case lightTunnel = "Light Tunnel"
    case solarize = "Solarize"
    case clouds = "Clouds"
    case differenceClouds = "Difference Clouds"
    case offset = "Offset"
    case cameraRaw = "Camera Raw Filter"
    case removeBackground = "Remove Background"
    case contentAwareFill = "Content-Aware Fill"
    case curves = "Curves"
    case exposure = "Exposure"
    case gradientMap = "Gradient Map"
    case grain = "Grain"
    case blackWhite = "Black & White"
    case colorBalance = "Color Balance"
    case brightnessContrast = "Brightness/Contrast"
    case shadowsHighlights = "Shadows/Highlights"
    case channelMixer = "Channel Mixer"
    case photoFilter = "Photo Filter"
    case selectiveColor = "Selective Color"
    case replaceColor = "Replace Color"
    case vibrance = "Vibrance"
    case posterize = "Posterize"
    case threshold = "Threshold"
    case desaturate = "Desaturate"
    case autoTone = "Auto Tone"
    case autoContrast = "Auto Contrast"
    case autoColor = "Auto Color"
    case equalize = "Equalize"
    /// The Image menu's one-click adjustments, which apply without a panel.
    static let imageMenuCommands: [Self] = [.desaturate, .autoTone, .autoContrast, .autoColor, .equalize]
    /// The Image menu's pixel adjustments, in its order. Their adjustment-layer versions are the Layer menu's own.
    static let imageMenuAdjustments: [Self] = [
        .blackWhite, .colorBalance, .exposure, .gradientMap, .grain, .brightnessContrast, .shadowsHighlights,
        .vibrance, .posterize, .threshold, .channelMixer, .photoFilter, .selectiveColor, .replaceColor,
    ]
    /// The filter's name as menus and editors show it, in the app's language; `rawValue` stays the project's.
    var displayName: String { rawValue.localized }
    var isAutomatic: Bool { self == .contentAwareFill || self == .removeBackground }
    /// The Filter menu's own filters, which Last Filter can run again; not Content-Aware Fill or the Image menu's.
    var repeatsAsLastFilter: Bool { self != .contentAwareFill && !isImageAdjustment }
    /// Filters made wholly in Core Image, which works at 16 bits as readily as at 8: a 16-bit layer runs them once, on its
    /// 16-bit pixels, rather than three times through `DeepLayer.run`.
    var runsAtSixteenBits: Bool {
        self == .gaussianBlur || self == .motionBlur || self == .progressiveBlur || self == .bloomGlow || self == .lensEffects
            || self == .sharpen || self == .rimLight || self == .volumetricLight
            || self == .brightnessContrast || self == .vibrance || self == .posterize || self == .threshold
            || self == .mosaic || self == .crystallize || self == .colorHalftone || self == .twirl || self == .pinch
            || self == .spherize || self == .vortex || self == .gloom || self == .kaleidoscope
            || self == .pointillize || self == .hexagonalPixelate || self == .hole || self == .circleSplash || self == .torusLens
            || self == .boxBlur || self == .zoomBlur || self == .bokehBlur || self == .median || self == .photoEffect
            || self == .shadowsHighlights
            || self == .findEdges || self == .comic || self == .lineScreen || self == .circularScreen
            || self == .hatchedScreen || self == .glass || self == .glassLozenge || self == .triangleKaleidoscope
            || self == .falseColor || self == .monochrome || self == .discBlur
            || self == .lensFlare || self == .lightTunnel || self == .solarize || self == .offset
            || self == .tiltShiftBlur || self == .irisBlur
            || self == .selectiveColor || self == .replaceColor
            || self == .desaturate || self == .autoTone || self == .autoContrast || self == .autoColor || self == .equalize
    }
    /// Filters whose output channels each depend on all three input channels (Camera Raw's color, and the ones that work
    /// from brightness), which a 16-bit layer runs the slower, channel-by-channel way (`DeepLayer.run`).
    var mixesChannels: Bool { self == .cameraRaw || self == .tonalContrast || self == .scanlines || self == .reduceNoise }
    /// For the color adjustments whose channels mix, their color lookup, to apply to a 16-bit layer
    /// (`LayerAdjustment.sixteenBitLookup`); nil for the rest.
    func sixteenBitLookup(_ settings: FilterSettings) -> (cube: Data, dimension: Int)? {
        var adjustment: LayerAdjustment
        switch self {
        case .blackWhite: adjustment = LayerAdjustment(kind: .blackWhite); adjustment.blackWhite = settings.blackWhite
        case .colorBalance: adjustment = LayerAdjustment(kind: .colorBalance); adjustment.colorBalance = settings.colorBalance
        case .gradientMap: adjustment = LayerAdjustment(kind: .gradientMap); adjustment.gradientMap = settings.gradientMap
        default: return nil
        }
        return adjustment.sixteenBitLookup
    }
    /// Color adjustments: in the Image menu (and editable as adjustment layers), not under Filter.
    var isImageAdjustment: Bool {
        self == .curves || self == .exposure || self == .gradientMap || self == .grain
            || self == .blackWhite || self == .colorBalance
            || self == .brightnessContrast || self == .vibrance || self == .posterize || self == .threshold
            || self == .shadowsHighlights || self == .channelMixer || self == .photoFilter
            || self == .selectiveColor || self == .replaceColor
            || self == .desaturate || self == .autoTone || self == .autoContrast || self == .autoColor || self == .equalize
    }
}

/// One of the photographic filters Photo Filter offers, each a tint with a name.
nonisolated enum PhotoFilterPreset: String, CaseIterable, Sendable {
    case warming85 = "Warming Filter (85)"
    case warming81 = "Warming Filter (81)"
    case warming80 = "Warming Filter (80)"
    case cooling80 = "Cooling Filter (80)"
    case cooling82 = "Cooling Filter (82)"
    case sepia = "Sepia"
    case deepRed = "Deep Red"
    case deepBlue = "Deep Blue"
    case deepEmerald = "Deep Emerald"
    case deepYellow = "Deep Yellow"
    var color: AdjustmentColor {
        switch self {
        case .warming85: AdjustmentColor(red: 0.93, green: 0.62, blue: 0.28)
        case .warming81: AdjustmentColor(red: 0.94, green: 0.72, blue: 0.45)
        case .warming80: AdjustmentColor(red: 0.96, green: 0.81, blue: 0.60)
        case .cooling80: AdjustmentColor(red: 0.55, green: 0.72, blue: 0.95)
        case .cooling82: AdjustmentColor(red: 0.70, green: 0.83, blue: 0.98)
        case .sepia: AdjustmentColor(red: 0.78, green: 0.63, blue: 0.42)
        case .deepRed: AdjustmentColor(red: 0.85, green: 0.20, blue: 0.20)
        case .deepBlue: AdjustmentColor(red: 0.25, green: 0.35, blue: 0.85)
        case .deepEmerald: AdjustmentColor(red: 0.20, green: 0.70, blue: 0.45)
        case .deepYellow: AdjustmentColor(red: 0.95, green: 0.90, blue: 0.25)
        }
    }
}

/// False Color's palettes: what the darkest and lightest tones of a picture become.
nonisolated enum FalseColorPalette: String, CaseIterable, Sendable {
    case thermal = "Thermal"
    case infrared = "Infrared"
    case rainbow = "Rainbow"
    case duotone = "Duotone"
    case gold = "Gold"
    case ice = "Ice"
    var dark: AdjustmentColor {
        switch self {
        case .thermal: AdjustmentColor(red: 0.02, green: 0.02, blue: 0.40)
        case .infrared: AdjustmentColor(red: 0.10, green: 0.00, blue: 0.30)
        case .rainbow: AdjustmentColor(red: 0.10, green: 0.00, blue: 0.60)
        case .duotone: AdjustmentColor(red: 0.05, green: 0.05, blue: 0.35)
        case .gold: AdjustmentColor(red: 0.15, green: 0.05, blue: 0.00)
        case .ice: AdjustmentColor(red: 0.00, green: 0.10, blue: 0.30)
        }
    }
    var light: AdjustmentColor {
        switch self {
        case .thermal: AdjustmentColor(red: 1.00, green: 0.85, blue: 0.10)
        case .infrared: AdjustmentColor(red: 0.95, green: 0.20, blue: 0.10)
        case .rainbow: AdjustmentColor(red: 0.20, green: 0.95, blue: 0.30)
        case .duotone: AdjustmentColor(red: 0.90, green: 0.90, blue: 0.95)
        case .gold: AdjustmentColor(red: 1.00, green: 0.85, blue: 0.40)
        case .ice: AdjustmentColor(red: 0.60, green: 0.90, blue: 1.00)
        }
    }
}

/// Monochrome's tints: the color a gray picture takes, from neutral to sepia and beyond.
nonisolated enum MonochromeTint: String, CaseIterable, Sendable {
    case neutral = "Neutral"
    case sepia = "Sepia"
    case cyanotype = "Cyanotype"
    case selenium = "Selenium"
    case gold = "Gold"
    case rose = "Rose"
    var color: AdjustmentColor {
        switch self {
        case .neutral: AdjustmentColor(red: 0.50, green: 0.50, blue: 0.50)
        case .sepia: AdjustmentColor(red: 0.55, green: 0.50, blue: 0.42)
        case .cyanotype: AdjustmentColor(red: 0.35, green: 0.55, blue: 0.75)
        case .selenium: AdjustmentColor(red: 0.50, green: 0.48, blue: 0.55)
        case .gold: AdjustmentColor(red: 0.70, green: 0.60, blue: 0.35)
        case .rose: AdjustmentColor(red: 0.75, green: 0.45, blue: 0.50)
        }
    }
}

/// Where Lens Flare's light sits on the layer.
nonisolated enum LensFlarePosition: String, CaseIterable, Sendable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    /// The light's place in the picture, from 0 to 1 across and up.
    func point(in extent: CGRect) -> CGPoint {
        let x: CGFloat, y: CGFloat
        switch self {
        case .center: x = 0.5; y = 0.5
        case .topLeft: x = 0.28; y = 0.72
        case .topRight: x = 0.72; y = 0.72
        case .bottomLeft: x = 0.28; y = 0.28
        case .bottomRight: x = 0.72; y = 0.28
        }
        return CGPoint(x: extent.minX + extent.width * x, y: extent.minY + extent.height * y)
    }
}

/// The color of Lens Flare's light.
nonisolated enum LensFlareTint: String, CaseIterable, Sendable {
    case white = "White"
    case warm = "Warm"
    case cool = "Cool"
    case violet = "Violet"
    var color: AdjustmentColor {
        switch self {
        case .white: AdjustmentColor(red: 1.00, green: 0.96, blue: 0.88)
        case .warm: AdjustmentColor(red: 1.00, green: 0.78, blue: 0.48)
        case .cool: AdjustmentColor(red: 0.68, green: 0.84, blue: 1.00)
        case .violet: AdjustmentColor(red: 0.80, green: 0.68, blue: 1.00)
        }
    }
}

/// Selective Color's nine families of color, each adjusted on its own.
nonisolated enum SelectiveColorFamily: String, CaseIterable, Sendable {
    case reds = "Reds"
    case yellows = "Yellows"
    case greens = "Greens"
    case cyans = "Cyans"
    case blues = "Blues"
    case magentas = "Magentas"
    case whites = "Whites"
    case neutrals = "Neutrals"
    case blacks = "Blacks"
    /// The hue at the middle of a family's range, in degrees; nil for the grays.
    var hue: Double? {
        switch self {
        case .reds: 0
        case .yellows: 60
        case .greens: 120
        case .cyans: 180
        case .blues: 240
        case .magentas: 300
        case .whites, .neutrals, .blacks: nil
        }
    }
}

/// How much one of Selective Color's families moves toward each ink, in percent.
nonisolated struct SelectiveColorAmounts: Equatable, Sendable {
    static let range: ClosedRange<Double> = -100...100
    var cyan: Double = 0
    var magenta: Double = 0
    var yellow: Double = 0
    var black: Double = 0
    var isIdentity: Bool { cyan == 0 && magenta == 0 && yellow == 0 && black == 0 }
    var normalized: Self {
        func clamp(_ value: Double) -> Double {
            value.isFinite ? min(Self.range.upperBound, max(Self.range.lowerBound, value)) : 0
        }
        return Self(cyan: clamp(cyan), magenta: clamp(magenta), yellow: clamp(yellow), black: clamp(black))
    }
}

/// The two colors Clouds makes its sky from.
nonisolated enum CloudsStyle: String, CaseIterable, Sendable {
    case gray = "Gray"
    case warm = "Warm"
    case cool = "Cool"
    case sunset = "Sunset"
    var dark: AdjustmentColor {
        switch self {
        case .gray: AdjustmentColor(red: 0.45, green: 0.45, blue: 0.45)
        case .warm: AdjustmentColor(red: 0.35, green: 0.25, blue: 0.15)
        case .cool: AdjustmentColor(red: 0.20, green: 0.30, blue: 0.45)
        case .sunset: AdjustmentColor(red: 0.35, green: 0.15, blue: 0.25)
        }
    }
    var light: AdjustmentColor {
        switch self {
        case .gray: AdjustmentColor(red: 0.95, green: 0.95, blue: 0.95)
        case .warm: AdjustmentColor(red: 1.00, green: 0.92, blue: 0.75)
        case .cool: AdjustmentColor(red: 0.85, green: 0.93, blue: 1.00)
        case .sunset: AdjustmentColor(red: 1.00, green: 0.70, blue: 0.35)
        }
    }
}

/// Remove Background's two ways of working: Apple's own subject mask on its own, or that mask refined against the
/// layer's detail, which recovers hair and fur but takes longer.
nonisolated enum BackgroundQuality: String, CaseIterable, Sendable {
    case basic = "Basic"
    case advanced = "Advanced"
}

/// One of Core Image's photographic looks, as the Photo Effect filter offers them.
nonisolated enum PhotoEffect: String, CaseIterable, Sendable {
    case transfer = "Transfer"
    case process = "Process"
    case chrome = "Chrome"
    case fade = "Fade"
    case instant = "Instant"
    case mono = "Mono"
    case noir = "Noir"
    case tonal = "Tonal"
    var filterName: String {
        switch self {
        case .transfer: "CIPhotoEffectTransfer"
        case .process: "CIPhotoEffectProcess"
        case .chrome: "CIPhotoEffectChrome"
        case .fade: "CIPhotoEffectFade"
        case .instant: "CIPhotoEffectInstant"
        case .mono: "CIPhotoEffectMono"
        case .noir: "CIPhotoEffectNoir"
        case .tonal: "CIPhotoEffectTonal"
        }
    }
}

/// Every filter's settings; each filter reads only its own.
nonisolated struct FilterSettings: Equatable, Sendable {
    /// Gaussian Blur radius in layer pixels (the blur's standard deviation), 0.1–250.
    var radius: Double = 5
    /// Gaussian Blur keeps every pixel's transparency: only the colors blur, from the layer's own pixels, so its
    /// outline stays where it is instead of softening and spreading.
    var preserveTransparency = false
    /// Motion Blur direction in degrees, counterclockwise from horizontal as in Photoshop, −90–90.
    var angle: Double = 0
    /// Motion Blur streak length in layer pixels, 1–2000.
    var distance: Double = 10
    /// Progressive Blur: the blur at the start of its line and at its end, in layer pixels (a Gaussian blur's radius),
    /// 0–250, changing evenly between them.
    var progressiveFrom: Double = 0
    var progressiveTo: Double = 20
    /// Where it runs, in document coordinates, set by dragging on the canvas: `progressiveFrom` at `progressiveStart`,
    /// `progressiveTo` at `progressiveEnd` and past it. Nil until the filter places it on the layer.
    var progressiveStart: CGPoint?
    var progressiveEnd: CGPoint?
    /// Radial: from the start outwards to the circle through the end, rather than along the line.
    var progressiveRadial = false
    /// From and To the other way round.
    var progressiveInverted = false
    /// Add Noise strength as Photoshop's percentage, 0.1–400.
    var amount: Double = 10
    /// Add Noise distribution: Gaussian (more speckled) instead of Uniform.
    var gaussian = false
    /// Add Noise changes brightness only, the same amount on every channel.
    var monochromatic = false
    /// Standalone vignette: edge color, strength, and shape of its falloff.
    var vignetteAmount: Double = 35
    var vignetteColor = AdjustmentColor(red: 0, green: 0, blue: 0)
    var vignetteMidpoint: Double = 50
    var vignetteRoundness: Double = 100
    var vignetteFeather: Double = 60
    var vignetteHighlights: Double = 25
    /// Bloom / Glow: strength and blur radius in layer pixels.
    var bloomAmount: Double = 40
    var bloomRadius: Double = 24
    /// Sharpen: how much of the detail to add back, 0–300%, and how fine it is, 0.1–20 layer pixels.
    var sharpenAmount: Double = 100
    var sharpenRadius: Double = 1
    /// Reduce Noise, as Camera Raw's noise reduction: how much grain is smoothed from the brightness, how much fine
    /// texture is kept from it, and how much colored speckle is smoothed, each 0–100.
    var reduceNoiseLuminance: Double = 50
    var reduceNoiseDetail: Double = 50
    var reduceNoiseColor: Double = 50
    /// Tonal Contrast: one local-detail radius and separate tonal strengths.
    var tonalAmount: Double = 50
    var tonalRadius: Double = 16
    var tonalShadows: Double = 40
    var tonalMidtones: Double = 60
    var tonalHighlights: Double = 30
    /// RGB Split: how far the spectrum spreads (red one way, blue the other, green staying), and how far it smears into
    /// streaks, in layer pixels; for Radial, at `rgbSplitReach` from the center, less nearer it and more beyond.
    var rgbSplitDistance: Double = 10
    var rgbSplitBlur: Double = 0
    /// Linear's direction, in degrees counterclockwise from horizontal.
    var rgbSplitAngle: Double = 0
    /// Radial: outwards from `rgbSplitCenter` (document coordinates, set by clicking the canvas) instead of along the
    /// angle. Reach is how far from the center the full distance applies, in document pixels: half the layer's
    /// visible diagonal when the filter opens.
    var rgbSplitRadial = false
    var rgbSplitCenter: CGPoint?
    var rgbSplitReach: Double = 1000
    /// Lens Correction's Remove Distortion, −100–100: positive straightens barrel distortion
    /// (lines bowing outward), negative straightens pincushion (lines bowing inward).
    var distortion: Double = 0
    var lens = LensEffectSettings()
    var rimLight = RimLightSettings()
    var volumetric = VolumetricLightSettings()
    var curves = CurvesSettings()
    var exposure = ExposureSettings()
    var gradientMap = GradientMapSettings()
    var grain = GrainSettings()
    var blackWhite = BlackWhiteSettings()
    var colorBalance = ColorBalanceSettings()
    /// Brightness/Contrast: how far the whole picture is lifted and how much its tones spread, each −100…100.
    var brightnessContrast = BrightnessContrastSettings()
    /// Shadows/Highlights: how much the dark or bright end is opened up, and the radius that decides what counts as local.
    var shadowsHighlights = ShadowsHighlightsSettings()
    /// Channel Mixer: how much of each input channel reaches each output channel, in percent.
    var channelMixer = ChannelMixerSettings()
    /// Photo Filter: the tint's preset, how strongly it shows, and whether the picture keeps its brightness.
    var photoFilterPreset: PhotoFilterPreset = .warming85
    var photoFilterDensity: Double = 25
    var photoFilterPreserveLuminosity = true
    /// Selective Color: the family its panel edits, and each family's own ink adjustments.
    var selectiveFamily: SelectiveColorFamily = .reds
    var selectiveReds = SelectiveColorAmounts()
    var selectiveYellows = SelectiveColorAmounts()
    var selectiveGreens = SelectiveColorAmounts()
    var selectiveCyans = SelectiveColorAmounts()
    var selectiveBlues = SelectiveColorAmounts()
    var selectiveMagentas = SelectiveColorAmounts()
    var selectiveWhites = SelectiveColorAmounts()
    var selectiveNeutrals = SelectiveColorAmounts()
    var selectiveBlacks = SelectiveColorAmounts()
    /// Replace Color: the hue to replace, how far around it to reach, and where those pixels go.
    var replaceTargetHue: Double = 0
    var replaceTolerance: Double = 60
    var replaceHue: Double = 120
    var replaceSaturation: Double = 0
    var replaceLightness: Double = 0
    /// Vibrance: how much muted colors are lifted while already-saturated ones stay put, −100…100.
    var vibranceAmount: Double = 0
    /// Posterize: how many levels each channel keeps, 2–255.
    var posterizeLevels: Double = 4
    /// Threshold: the brightness that splits the picture into black and white, 0–255.
    var thresholdLevel: Double = 128
    /// Mosaic: the size of each square block, in layer pixels.
    var mosaicCellSize: Double = 10
    /// Crystallize: the size of each crystal, in layer pixels.
    var crystallizeSize: Double = 10
    /// Pointillize and Hexagonal Pixelate: the size of each dot or hexagon, in layer pixels.
    var pointillizeSize: Double = 10
    var hexagonalPixelateSize: Double = 10
    /// Hole, Circle Splash and Torus Lens: the radius of the effect, in layer pixels.
    var holeRadius: Double = 60
    var circleSplashRadius: Double = 60
    var torusLensRadius: Double = 80
    /// Torus Lens: how wide the ring is and how strongly it bends the light.
    var torusLensWidth: Double = 40
    var torusLensRefraction: Double = 1.5
    /// Color Halftone: its dot width, screen angle and dot sharpness.
    var halftoneWidth: Double = 8
    var halftoneAngle: Double = 15
    var halftoneSharpness: Double = 50
    /// Twirl: how far the center turns, in degrees.
    var twirlAngle: Double = 60
    /// Pinch and Spherize: how strongly the layer's middle is pulled in or pushed out, 0–100.
    var pinchAmount: Double = 50
    var spherizeAmount: Double = 50
    /// Vortex: how far the center swirls around, in degrees.
    var vortexAngle: Double = 60
    /// Gloom: the glow's blur radius in layer pixels, and its strength, 0–100.
    var gloomRadius: Double = 10
    var gloomIntensity: Double = 50
    /// Kaleidoscope: how many mirrored slices, and how far they are turned, in degrees.
    var kaleidoscopeCount: Double = 6
    var kaleidoscopeAngle: Double = 0
    /// Box Blur: its radius in layer pixels.
    var boxBlurRadius: Double = 10
    /// Zoom Blur: how far the blur streaks outward from the center, in layer pixels.
    var zoomAmount: Double = 10
    /// Bokeh Blur: the disc size, how much light gathers at its rim, how big that rim is, and how soft its edge is.
    var bokehRadius: Double = 20
    var bokehRingAmount: Double = 0
    var bokehRingSize: Double = 50
    var bokehSoftness: Double = 5
    /// Photo Effect: which of Core Image's photographic looks to apply.
    var photoEffect: PhotoEffect = .transfer
    /// Find Edges: how strongly the edges show, 1–10.
    var edgesIntensity: Double = 2
    /// Glass: how far the random texture pushes pixels, in layer pixels.
    var glassScale: Double = 100
    /// Glass Lozenge: the lens's radius, and how strongly it bends the light.
    var glassLensRadius: Double = 200
    var glassRefraction: Double = 1.7
    /// Triangle Kaleidoscope: the size of the mirrored triangle, how far it is turned, and how fast it fades.
    var triangleKaleidoscopeSize: Double = 250
    var triangleKaleidoscopeRotation: Double = 0
    var triangleKaleidoscopeDecay: Double = 0.5
    /// False Color: the colors the darkest and lightest tones become.
    var falseColorPalette: FalseColorPalette = .thermal
    /// Monochrome: the tint the picture takes, and how much of it shows, 0–100.
    var monochromeTint: MonochromeTint = .neutral
    var monochromeAmount: Double = 100
    /// Disc Blur: its radius in layer pixels.
    var discBlurRadius: Double = 8
    /// Wave and Ripple: how far pixels move, the distance between crests, and where the wave starts, in degrees.
    var waveAmplitude: Double = 10
    var waveLength: Double = 60
    var wavePhase: Double = 0
    /// Wave runs up and down rather than side to side.
    var waveVertical = false
    /// Tilt-Shift Blur: its blur radius, where the sharp band sits, how wide it is and how far it is turned.
    var tiltShiftRadius: Double = 20
    var tiltShiftFocus: Double = 50
    var tiltShiftBand: Double = 20
    var tiltShiftAngle: Double = 0
    /// Iris Blur: the sharp circle's radius, how far its edge feathers, and the blur's radius.
    var irisBlurRadius: Double = 20
    var irisRadius: Double = 100
    var irisFeather: Double = 50
    /// Lens Flare: where the light sits, its tint, how bright it is (0–200%), and how large it spreads.
    var lensFlarePosition: LensFlarePosition = .center
    var lensFlareTint: LensFlareTint = .white
    var lensFlareBrightness: Double = 100
    var lensFlareSize: Double = 120
    /// Light Tunnel: the tunnel's radius and how far it twists, in degrees.
    var lightTunnelRadius: Double = 80
    var lightTunnelRotation: Double = 30
    /// Solarize: the brightness above which tones invert, 0–255.
    var solarizeThreshold: Double = 128
    /// Clouds: the size of the largest cloud, how many finer octaves it has, its colors, and the seed that fixes its shape.
    var cloudsScale: Double = 60
    var cloudsDetail: Double = 50
    var cloudsStyle: CloudsStyle = .gray
    var cloudsSeed: UInt32 = 0
    /// Offset: how far the layer moves, in layer pixels, and whether what leaves one side comes back on the other.
    var offsetX: Double = 0
    var offsetY: Double = 0
    var offsetWrap = true
    var dither = DitherSettings()
    var scanlines = ScanlinesSettings()
    var cameraRaw = CameraRawSettings()
    /// Remove Background: Basic is the quick subject mask; Advanced refines it (see the three settings below).
    var backgroundQuality: BackgroundQuality = .basic
    /// Remove Background: how far the mask is pulled onto the image's own edges (0 off, in layer pixels).
    var refineEdges: Double = 12
    /// Remove Background: pushes the mask's grays toward black and white, 0–100, clearing haze in thin areas.
    var matteContrast: Double = 25
    /// Remove Background: contracts (negative) or expands (positive) the mask edge, in layer pixels.
    var shiftEdge: Double = 0
    var normalized: Self {
        func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        var result = self
        result.radius = clamp(radius, 0.1...250, 5)
        result.angle = clamp(angle, -90...90, 0)
        result.distance = clamp(distance, 1...2000, 10)
        result.progressiveFrom = clamp(progressiveFrom, 0...250, 0)
        result.progressiveTo = clamp(progressiveTo, 0...250, 20)
        result.amount = clamp(amount, 0.1...400, 10)
        result.vignetteAmount = clamp(vignetteAmount, 0...100, 35)
        result.vignetteColor = vignetteColor.clamped
        result.vignetteMidpoint = clamp(vignetteMidpoint, 0...100, 50)
        result.vignetteRoundness = clamp(vignetteRoundness, -100...100, 100)
        result.vignetteFeather = clamp(vignetteFeather, 0...100, 60)
        result.vignetteHighlights = clamp(vignetteHighlights, 0...100, 25)
        result.bloomAmount = clamp(bloomAmount, 0...100, 40)
        result.sharpenAmount = clamp(sharpenAmount, 0...300, 100)
        result.sharpenRadius = clamp(sharpenRadius, 0.1...20, 1)
        result.reduceNoiseLuminance = clamp(reduceNoiseLuminance, 0...100, 50)
        result.reduceNoiseDetail = clamp(reduceNoiseDetail, 0...100, 50)
        result.reduceNoiseColor = clamp(reduceNoiseColor, 0...100, 50)
        result.bloomRadius = clamp(bloomRadius, 1...150, 24)
        result.tonalAmount = clamp(tonalAmount, 0...100, 50)
        result.tonalRadius = clamp(tonalRadius, 1...100, 16)
        result.tonalShadows = clamp(tonalShadows, -100...100, 40)
        result.tonalMidtones = clamp(tonalMidtones, -100...100, 60)
        result.tonalHighlights = clamp(tonalHighlights, -100...100, 30)
        result.distortion = clamp(distortion, -100...100, 0)
        result.rgbSplitDistance = clamp(rgbSplitDistance, 0...200, 10)
        result.rgbSplitBlur = clamp(rgbSplitBlur, 0...400, 0)
        result.rgbSplitAngle = clamp(rgbSplitAngle, -180...180, 0)
        result.rgbSplitReach = clamp(rgbSplitReach, 1...100_000, 1000)
        result.refineEdges = clamp(refineEdges, 0...40, 12)
        result.matteContrast = clamp(matteContrast, 0...100, 25)
        result.shiftEdge = clamp(shiftEdge, -10...10, 0)
        result.exposure = exposure.normalized
        result.gradientMap = gradientMap.normalized
        result.grain = grain.normalized
        result.blackWhite = blackWhite.normalized
        result.colorBalance = colorBalance.normalized
        result.brightnessContrast = brightnessContrast.normalized
        result.vibranceAmount = clamp(vibranceAmount, -100...100, 0)
        result.posterizeLevels = clamp(posterizeLevels, 2...255, 4)
        result.thresholdLevel = clamp(thresholdLevel, 0...255, 128)
        result.mosaicCellSize = clamp(mosaicCellSize, 2...200, 10)
        result.crystallizeSize = clamp(crystallizeSize, 1...100, 10)
        result.pointillizeSize = clamp(pointillizeSize, 2...100, 10)
        result.hexagonalPixelateSize = clamp(hexagonalPixelateSize, 2...100, 10)
        result.holeRadius = clamp(holeRadius, 1...500, 60)
        result.circleSplashRadius = clamp(circleSplashRadius, 1...500, 60)
        result.torusLensRadius = clamp(torusLensRadius, 1...500, 80)
        result.torusLensWidth = clamp(torusLensWidth, 1...200, 40)
        result.torusLensRefraction = clamp(torusLensRefraction, 0...5, 1.5)
        result.halftoneWidth = clamp(halftoneWidth, 4...100, 8)
        result.halftoneAngle = clamp(halftoneAngle, -360...360, 15)
        result.halftoneSharpness = clamp(halftoneSharpness, 0...100, 50)
        result.twirlAngle = clamp(twirlAngle, -999...999, 60)
        result.pinchAmount = clamp(pinchAmount, 0...100, 50)
        result.spherizeAmount = clamp(spherizeAmount, 0...100, 50)
        result.vortexAngle = clamp(vortexAngle, -999...999, 60)
        result.gloomRadius = clamp(gloomRadius, 1...100, 10)
        result.gloomIntensity = clamp(gloomIntensity, 0...100, 50)
        result.kaleidoscopeCount = clamp(kaleidoscopeCount, 2...20, 6)
        result.kaleidoscopeAngle = clamp(kaleidoscopeAngle, -360...360, 0)
        result.boxBlurRadius = clamp(boxBlurRadius, 1...500, 10)
        result.zoomAmount = clamp(zoomAmount, 0...100, 10)
        result.bokehRadius = clamp(bokehRadius, 1...100, 20)
        result.bokehRingAmount = clamp(bokehRingAmount, 0...100, 0)
        result.bokehRingSize = clamp(bokehRingSize, 0...100, 50)
        result.bokehSoftness = clamp(bokehSoftness, 0...100, 5)
        result.shadowsHighlights = shadowsHighlights.normalized
        result.channelMixer = channelMixer.normalized
        result.photoFilterDensity = clamp(photoFilterDensity, 0...100, 25)
        result.selectiveReds = selectiveReds.normalized
        result.selectiveYellows = selectiveYellows.normalized
        result.selectiveGreens = selectiveGreens.normalized
        result.selectiveCyans = selectiveCyans.normalized
        result.selectiveBlues = selectiveBlues.normalized
        result.selectiveMagentas = selectiveMagentas.normalized
        result.selectiveWhites = selectiveWhites.normalized
        result.selectiveNeutrals = selectiveNeutrals.normalized
        result.selectiveBlacks = selectiveBlacks.normalized
        result.replaceTargetHue = clamp(replaceTargetHue, 0...360, 0)
        result.replaceTolerance = clamp(replaceTolerance, 0...180, 60)
        result.replaceHue = clamp(replaceHue, 0...360, 120)
        result.replaceSaturation = clamp(replaceSaturation, -100...100, 0)
        result.replaceLightness = clamp(replaceLightness, -100...100, 0)
        result.edgesIntensity = clamp(edgesIntensity, 1...10, 2)
        result.glassScale = clamp(glassScale, 1...500, 100)
        result.glassLensRadius = clamp(glassLensRadius, 1...1000, 200)
        result.glassRefraction = clamp(glassRefraction, 0...5, 1.7)
        result.triangleKaleidoscopeSize = clamp(triangleKaleidoscopeSize, 10...2000, 250)
        result.triangleKaleidoscopeRotation = clamp(triangleKaleidoscopeRotation, -360...360, 0)
        result.triangleKaleidoscopeDecay = clamp(triangleKaleidoscopeDecay, 0...1, 0.5)
        result.falseColorPalette = falseColorPalette
        result.monochromeTint = monochromeTint
        result.monochromeAmount = clamp(monochromeAmount, 0...100, 100)
        result.discBlurRadius = clamp(discBlurRadius, 1...500, 8)
        result.waveAmplitude = clamp(waveAmplitude, 0...200, 10)
        result.waveLength = clamp(waveLength, 1...1000, 60)
        result.wavePhase = clamp(wavePhase, -360...360, 0)
        result.tiltShiftRadius = clamp(tiltShiftRadius, 0.1...250, 20)
        result.tiltShiftFocus = clamp(tiltShiftFocus, 0...100, 50)
        result.tiltShiftBand = clamp(tiltShiftBand, 0...100, 20)
        result.tiltShiftAngle = clamp(tiltShiftAngle, -90...90, 0)
        result.irisBlurRadius = clamp(irisBlurRadius, 0.1...250, 20)
        result.irisRadius = clamp(irisRadius, 1...1000, 100)
        result.irisFeather = clamp(irisFeather, 0...100, 50)
        result.lensFlareBrightness = clamp(lensFlareBrightness, 0...200, 100)
        result.lensFlareSize = clamp(lensFlareSize, 10...1000, 120)
        result.lightTunnelRadius = clamp(lightTunnelRadius, 1...500, 80)
        result.lightTunnelRotation = clamp(lightTunnelRotation, -360...360, 30)
        result.solarizeThreshold = clamp(solarizeThreshold, 0...255, 128)
        result.cloudsScale = clamp(cloudsScale, 2...500, 60)
        result.cloudsDetail = clamp(cloudsDetail, 0...100, 50)
        result.offsetX = clamp(offsetX, -1000...1000, 0)
        result.offsetY = clamp(offsetY, -1000...1000, 0)
        result.dither = dither.normalized
        result.scanlines = scanlines.normalized
        result.lens = lens.normalized
        result.rimLight = rimLight.normalized
        result.volumetric = volumetric.normalized
        result.cameraRaw = cameraRaw.normalized
        return result
    }
    /// Selective Color's inks, in `SelectiveColorFamily.allCases` order.
    var selectiveAmounts: [SelectiveColorAmounts] {
        [selectiveReds, selectiveYellows, selectiveGreens, selectiveCyans, selectiveBlues, selectiveMagentas,
         selectiveWhites, selectiveNeutrals, selectiveBlacks]
    }
    var hasSelectiveColor: Bool { selectiveAmounts.contains { !$0.isIdentity } }
}

/// Sides of a layer, in its own pixels (top is row 0).
nonisolated struct LayerSides: OptionSet, Sendable {
    let rawValue: Int
    static let left = Self(rawValue: 1), right = Self(rawValue: 2), top = Self(rawValue: 4), bottom = Self(rawValue: 8)
}

nonisolated struct FilterJob: @unchecked Sendable {
    let kind: FilterKind
    var image: CGImage
    let settings: FilterSettings
    /// Pixels in `image` per original layer pixel, so a downscaled preview blurs proportionally less.
    let scale: CGFloat
    let selection: SelectionClip?
    let mapping: CGAffineTransform
    /// Add Noise's random pattern: the same seed gives the same grain.
    var seed: UInt32 = 0
    /// Lens Effects' measure, in this image's pixels: the whole document's longer side, when the image is only part of
    /// it. Nil: the image's own.
    var lensSide: CGFloat?
    /// Vignette on an empty layer: the canvas, in the document, which it frames and fills. Otherwise the vignette
    /// frames the layer's own pixels and recolors only those.
    var canvas: CGRect? = nil
    /// The image's sides at the canvas's edge, which Gaussian and Motion Blur carry on past instead of fading.
    var canvasSides: LayerSides = []
    /// Canvas-space origin used by live adjustment layers so partial redraws keep one noise field.
    var noiseOrigin: CGPoint = .zero
    /// A 16-bit layer's pixels, for a filter that works in Core Image (`FilterKind.runsAtSixteenBits`): rendered at 16 bits.
    var sixteenBit = false
    /// Camera Raw's Option-drag clipping view. Preview only; committing leaves this nil.
    var cameraRawClipping: CameraRawClipping? = nil
    /// Persistent histogram clipping indicators. Preview only; committing leaves these off.
    var showsShadowClipping = false
    var showsHighlightClipping = false
    /// What Camera Raw's adaptive sliders read from `image`, when known already: measured once for a session's previews.
    var cameraRawBrightness: CameraRawTables.Brightness? = nil
    /// Preview only: the CPU remains the reference for OK, export, and unsupported GPU paths.
    var cameraRawUsesGPU = false
    /// Point-color range preview. −1 leaves the grade alone.
    var visualizesPointColor = -1
    /// Option-drag on Sharpening Masking. Preview only.
    var showsSharpenMask = false
}

nonisolated enum PixelFilter {
    /// `image` cropped to the pixels that are actually there, with the transform that keeps them in place: a blur
    /// is given generous room to spread, and whatever it leaves empty is cut away again.
    static func trimmed(_ image: CGImage, placed: LayerTransform) throws -> (image: CGImage, transform: LayerTransform) {
        guard let crop = try trimCrop(image), let cropped = image.cropping(to: crop) else { return (image, placed) }
        return (cropped, trimmedTransform(placed, crop: crop, width: image.width, height: image.height))
    }
    /// The part of `image` with anything in it, or nil when that's all of it (or nothing).
    static func trimCrop(_ image: CGImage) throws -> CGRect? {
        let full = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let context = try BrushRaster.context(width: image.width, height: image.height, mask: false)
        BrushRaster.draw(image, in: full, mask: false, context: context)
        guard let data = context.data else { throw ExportError.render }
        var edges = [Int](repeating: 0, count: 4)
        brush_alpha_bounds(data.assumingMemoryBound(to: UInt8.self), image.width, image.height, context.bytesPerRow, &edges)
        let crop = CGRect(x: edges[0], y: edges[1], width: edges[2] - edges[0], height: edges[3] - edges[1])
        return crop.width >= 1 && crop.height >= 1 && crop != full ? crop : nil
    }
    /// The transform placing `crop` of an image `width` × `height` that was placed by `placed`.
    static func trimmedTransform(_ placed: LayerTransform, crop: CGRect, width: Int, height: Int) -> LayerTransform {
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        var result = placed
        result.size = CGSize(width: crop.width * placed.size.width / full.width,
                             height: crop.height * placed.size.height / full.height)
        let toDocument = BrushRaster.pixelToDocument(placed, width: width, height: height)
        let middle = CGPoint(x: crop.midX, y: crop.midY).applying(toDocument)
        result.origin = CGPoint(x: middle.x - result.size.width / 2, y: middle.y - result.size.height / 2)
        return result
    }

    /// `CIMotionBlur`'s radius per pixel of streak length. Photoshop smears evenly along the whole
    /// distance; Core Image tapers like a Gaussian whose spread is about its radius (measured on a
    /// single dot). An even streak of length d spreads d / √12, so this radius matches its spread.
    static let motionRadiusPerPixel = 1 / 12.0.squareRoot()
    /// Remove Distortion at ±100 moves the image's corners by this share of their distance from the center.
    static let lensStrength = 0.35

    /// The image with its edge pixels carried on past `sides`, as Photoshop's blurs do at the canvas's edge: there
    /// is nothing clear beyond it to blur into, so a picture filling the canvas keeps solid edges. Past its other
    /// sides it stays clear, and a blur spreads into that.
    static func extending(_ image: CIImage, past sides: LayerSides, of extent: CGRect) -> CIImage {
        guard !sides.isEmpty else { return image }
        // Far enough for any blur; Core Image's y axis points up, so the layer's top is the extent's maxY.
        let far: CGFloat = 100_000
        var region = extent
        if sides.contains(.left) { region.origin.x -= far; region.size.width += far }
        if sides.contains(.right) { region.size.width += far }
        if sides.contains(.bottom) { region.origin.y -= far; region.size.height += far }
        if sides.contains(.top) { region.size.height += far }
        return image.clampedToExtent().cropped(to: region)
    }

    /// RGB Split: the layer dispersed on the GPU (see `MetalDispersion`), in the job's pixels.
    static func rgbSplit(_ job: FilterJob, settings: FilterSettings) throws -> CGImage {
        let width = job.image.width, height = job.image.height
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        BrushRaster.draw(job.image, in: CGRect(x: 0, y: 0, width: width, height: height), mask: false, context: context)
        let distance = settings.rgbSplitDistance * job.scale, blur = settings.rgbSplitBlur * job.scale
        guard distance > 0 || blur > 0 else { return job.image }
        guard let gpu = MetalDispersion.shared else { throw ExportError.render }
        // The center and reach, from the document into this image's pixels (rows top-down).
        let toPixels = job.mapping.inverted()
        let center = settings.rgbSplitCenter?.applying(toPixels) ?? CGPoint(x: Double(width) / 2, y: Double(height) / 2)
        let reach = settings.rgbSplitReach * hypot(toPixels.a, toPixels.b)
        let angle = settings.rgbSplitAngle * .pi / 180
        let sides = job.canvasSides
        // Enough samples that neighbors sit a pixel or two apart, within what the GPU does at once.
        let spread = settings.rgbSplitRadial ? distance * 2 : distance, smear = settings.rgbSplitRadial ? blur * 2 : blur
        try gpu.run(context, MetalDispersion.Parameters(
            center: SIMD2(Float(center.x), Float(center.y)),
            // Rows run top-down here, so up on screen is a smaller row.
            direction: SIMD2(Float(cos(angle)), Float(-sin(angle))),
            distance: Float(distance), blur: Float(blur), reach: Float(reach), radial: settings.rgbSplitRadial ? 1 : 0,
            sides: UInt32((sides.contains(.left) ? 1 : 0) | (sides.contains(.right) ? 2 : 0) | (sides.contains(.top) ? 4 : 0)
                | (sides.contains(.bottom) ? 8 : 0)),
            spectral: distance > 0 ? UInt32(min(32, max(3, Int(spread)))) : 1,
            smear: blur > 0 ? UInt32(min(24, max(2, Int(smear / 2)))) : 1))
        guard let image = context.makeImage() else { throw ExportError.render }
        return image
    }

    /// Reduce Noise on 8-bit premultiplied RGBA, in place: Camera Raw's noise reduction on its own, its contrast and color
    /// smoothness at their defaults. The filter, and a Reduce Noise layer on the canvas (`GPUReduceNoise`).
    static func reduceNoise(_ pixels: UnsafeMutablePointer<UInt8>, width: Int, height: Int, bytesPerRow: Int, settings: FilterSettings,
                            scale: CGFloat) {
        _ = MetalNonlocalMeans.installed
        adjust_camera_raw_detail(pixels, width, height, bytesPerRow, 0, 0, 0, 0, settings.reduceNoiseLuminance, settings.reduceNoiseDetail,
                                 0, settings.reduceNoiseColor, 50, 50, scale)
    }

    static func run(_ job: FilterJob) throws -> CGImage {
        // The filters' deepest paths overflow a concurrency thread's small stack; the pixel worker has room.
        try BigStack.run { try runBody(job) }
    }

    private static func runBody(_ job: FilterJob) throws -> CGImage {
        let settings = job.settings.normalized
        let width = job.image.width, height = job.image.height
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        // Not clamped: a blur softens the layer's edges and spreads into the room made for it, rather than
        // smearing the border outwards and stopping at it.
        let edges = CIImage(cgImage: job.image)
        let image: CGImage
        switch job.kind {
        case .curves: image = try settings.curves.apply(job.image)
        case .exposure: image = try settings.exposure.apply(job.image)
        case .gradientMap: image = try settings.gradientMap.apply(job.image)
        case .blackWhite: image = try settings.blackWhite.apply(job.image)
        case .colorBalance: image = try settings.colorBalance.apply(job.image)
        case .cameraRaw: image = try settings.cameraRaw.apply(job.image, clipping: job.cameraRawClipping, scale: job.scale, seed: job.seed,
                                                                visualizePointColor: job.visualizesPointColor, sharpenMask: job.showsSharpenMask,
                                                                brightness: job.cameraRawBrightness, usesGPU: job.cameraRawUsesGPU)
        // Grain sits in layer pixels; the job's seed gives each application its own pattern.
        case .grain: image = try settings.grain.apply(job.image, unitsPerPixel: 1 / job.scale, seed: job.seed)
        case .dither: image = try settings.dither.apply(job.image)
        case .scanlines: image = try settings.scanlines.apply(job.image)
        case .removeBackground:
            image = try SubjectRemoval.run(job.image, settings: settings)
        case .contentAwareFill:
            image = try ContentFill.run(job)
        case .gaussianBlur:
            let source = settings.preserveTransparency ? edges : extending(edges, past: job.canvasSides, of: extent)
            var blurred = source.applyingGaussianBlur(sigma: settings.radius * job.scale)
            if settings.preserveTransparency {
                // Each color from the layer's own pixels: dividing by the blurred alpha takes out the pull of the
                // clear ones around them, which would otherwise darken and thin the colors near the outline. Then
                // the original alpha, so the outline doesn't move.
                blurred = blurred.unpremultiplyingAlpha().settingAlphaOne(in: extent)
                    .applyingFilter("CIBlendWithAlphaMask", parameters: [
                        kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: edges,
                    ])
            }
            image = try render(blurred.cropped(to: extent), job: job)
        case .progressiveBlur:
            image = try render(progressivelyBlurred(edges, job: job, settings: settings, extent: extent).cropped(to: extent), job: job)
        case .rgbSplit: image = try rgbSplit(job, settings: settings)
        case .lensEffects:
            let side = job.lensSide ?? CGFloat(max(job.image.width, job.image.height))
            image = try render(settings.lens.apply(to: CIImage(cgImage: job.image), side: side), job: job)
        case .rimLight:
            image = try render(RimLighting.apply(to: CIImage(cgImage: job.image), source: job.image, settings: settings.rimLight), job: job)
        case .volumetricLight:
            // The light from the document into this image's pixels (rows top-down), then Core Image's (y up).
            let pixel = settings.volumetric.center?.applying(job.mapping.inverted())
                ?? VolumetricLighting.brightestPoint(in: job.image)
            image = try render(VolumetricLighting.apply(to: CIImage(cgImage: job.image), source: job.image, settings: settings.volumetric,
                                                        light: CGPoint(x: pixel.x, y: Double(height) - pixel.y)), job: job)
        case .motionBlur:
            // Core Image's y axis points up, so its counterclockwise angle matches Photoshop's.
            let radius = settings.distance * job.scale * motionRadiusPerPixel
            let angle = settings.angle * .pi / 180
            var streaked = extending(edges, past: job.canvasSides, of: extent).applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: radius,
                kCIInputAngleKey: angle,
            ])
            // Its kernel leaves alpha a few percent under the source's, which would veil a picture that fills
            // the canvas; put that back.
            let gain = motionBlurAlphaGain(radius: radius, angle: angle)
            if gain > 1 {
                streaked = streaked.applyingFilter("CIColorMatrix", parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: gain),
                ])
            }
            image = try render(streaked.cropped(to: extent), job: job)
        case .addNoise:
            // C, not Core Image: its random generator is uniform only, and Gaussian noise is needed too.
            let context = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: context)
            guard let data = context.data else { throw ExportError.render }
            noise_add_at(data.assumingMemoryBound(to: UInt8.self), width, height, context.bytesPerRow,
                         Float(settings.amount), settings.gaussian ? 1 : 0, settings.monochromatic ? 1 : 0, job.seed,
                         Int64(job.noiseOrigin.x.rounded(.down)), Int64(job.noiseOrigin.y.rounded(.down)))
            guard let noisy = context.makeImage() else { throw ExportError.render }
            image = noisy
        case .vignette:
            let context = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: context)
            guard let data = context.data else { throw ExportError.render }
            // The canvas in this image's pixels; bottom-up, as the context's rows are.
            let frame = job.canvas.map { $0.applying(job.mapping.inverted()) } ?? extent
            adjust_colored_vignette(data.assumingMemoryBound(to: UInt8.self), width, height, context.bytesPerRow,
                                    frame.minX, CGFloat(height) - frame.maxY, frame.width, frame.height, job.canvas == nil ? 0 : 1,
                                    settings.vignetteAmount, settings.vignetteMidpoint, settings.vignetteRoundness,
                                    settings.vignetteFeather, settings.vignetteHighlights,
                                    settings.vignetteColor.red, settings.vignetteColor.green, settings.vignetteColor.blue)
            guard let result = context.makeImage() else { throw ExportError.render }
            image = result
        case .sharpen:
            // An unsharp mask: the difference from a blur of `sharpenRadius` added back, `sharpenAmount` percent of it.
            // Edge pixels carry on past the canvas's sides, so the picture's border doesn't darken.
            let sharpened = extending(edges, past: job.canvasSides, of: extent).applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: settings.sharpenRadius * job.scale,
                kCIInputIntensityKey: settings.sharpenAmount / 100,
            ])
            image = try render(sharpened.cropped(to: extent), job: job)
        case .reduceNoise:
            let context = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: context)
            guard let data = context.data else { throw ExportError.render }
            reduceNoise(data.assumingMemoryBound(to: UInt8.self), width: width, height: height, bytesPerRow: context.bytesPerRow,
                        settings: settings, scale: job.scale)
            guard let result = context.makeImage() else { throw ExportError.render }
            image = result
        case .bloomGlow:
            let bloomed = edges.applyingFilter("CIBloom", parameters: [
                kCIInputRadiusKey: settings.bloomRadius * job.scale,
                kCIInputIntensityKey: settings.bloomAmount / 50,
            ])
            image = try render(bloomed.cropped(to: extent), job: job)
        case .tonalContrast:
            let blurred = edges.applyingGaussianBlur(sigma: settings.tonalRadius * job.scale)
            let base = try PixelAdjust.render(blurred.cropped(to: extent), width: width, height: height, isMask: false)
            let context = try BrushRaster.context(width: width, height: height, mask: false)
            let baseContext = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: context)
            BrushRaster.draw(base, in: extent, mask: false, context: baseContext)
            guard let data = context.data, let baseData = baseContext.data else { throw ExportError.render }
            adjust_tonal_contrast(data.assumingMemoryBound(to: UInt8.self),
                                  baseData.assumingMemoryBound(to: UInt8.self),
                                  width, height, context.bytesPerRow, baseContext.bytesPerRow,
                                  settings.tonalAmount, settings.tonalShadows,
                                  settings.tonalMidtones, settings.tonalHighlights)
            guard let result = context.makeImage() else { throw ExportError.render }
            image = result
        case .lensCorrection:
            // The warp is relative to the image's own size, so a downscaled preview bends the same way.
            let source = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: source)
            let destination = try BrushRaster.context(width: width, height: height, mask: false)
            guard let from = source.data, let into = destination.data else { throw ExportError.render }
            lens_distort(from.assumingMemoryBound(to: UInt8.self), into.assumingMemoryBound(to: UInt8.self),
                         width, height, source.bytesPerRow, settings.distortion / 100 * lensStrength)
            guard let corrected = destination.makeImage() else { throw ExportError.render }
            image = corrected
        case .wave, .ripple:
            let source = try BrushRaster.context(width: width, height: height, mask: false)
            BrushRaster.draw(job.image, in: extent, mask: false, context: source)
            let destination = try BrushRaster.context(width: width, height: height, mask: false)
            guard let from = source.data, let into = destination.data else { throw ExportError.render }
            let mode: Int32 = job.kind == .ripple ? 2 : (settings.waveVertical ? 1 : 0)
            wave_distort(from.assumingMemoryBound(to: UInt8.self), into.assumingMemoryBound(to: UInt8.self),
                         width, height, source.bytesPerRow,
                         settings.waveAmplitude * Double(job.scale), settings.waveLength * Double(job.scale),
                         settings.wavePhase * .pi / 180, mode)
            guard let distorted = destination.makeImage() else { throw ExportError.render }
            image = distorted
        case .brightnessContrast:
            let tone = settings.brightnessContrast
            guard tone.brightness != 0 || tone.contrast != 0 else { image = job.image; break }
            let adjusted = edges.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: tone.brightness / 200,
                kCIInputContrastKey: 1 + tone.contrast / 100,
            ])
            image = try render(adjusted.cropped(to: extent), job: job)
        case .channelMixer:
            let mixer = settings.channelMixer
            guard !mixer.isIdentity else { image = job.image; break }
            let red = CIVector(x: mixer.redFromRed / 100, y: mixer.redFromGreen / 100, z: mixer.redFromBlue / 100, w: 0)
            let green: CIVector, blue: CIVector, bias: CIVector
            if mixer.monochrome {
                green = red; blue = red
                bias = CIVector(x: mixer.redConstant / 100, y: mixer.redConstant / 100, z: mixer.redConstant / 100, w: 0)
            } else {
                green = CIVector(x: mixer.greenFromRed / 100, y: mixer.greenFromGreen / 100, z: mixer.greenFromBlue / 100, w: 0)
                blue = CIVector(x: mixer.blueFromRed / 100, y: mixer.blueFromGreen / 100, z: mixer.blueFromBlue / 100, w: 0)
                bias = CIVector(x: mixer.redConstant / 100, y: mixer.greenConstant / 100, z: mixer.blueConstant / 100, w: 0)
            }
            let mixed = edges.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": red, "inputGVector": green, "inputBVector": blue,
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputBiasVector": bias,
            ])
            image = try render(mixed.cropped(to: extent), job: job)
        case .photoFilter:
            guard settings.photoFilterDensity > 0 else { image = job.image; break }
            let tintColor = settings.photoFilterPreset.color
            let tint = CIImage(color: CIColor(red: tintColor.red, green: tintColor.green, blue: tintColor.blue)).cropped(to: extent)
            let tinted = tint.applyingFilter(settings.photoFilterPreserveLuminosity ? "CIColorBlendMode" : "CIMultiplyBlendMode",
                                             parameters: [kCIInputBackgroundImageKey: edges])
            let mixed = tinted.applyingFilter("CIMix", parameters: [
                kCIInputBackgroundImageKey: edges,
                "inputAmount": settings.photoFilterDensity / 100,
            ])
            image = try render(mixed.cropped(to: extent), job: job)
        case .selectiveColor:
            guard settings.hasSelectiveColor else { image = job.image; break }
            let adjusted = edges.applyingFilter("CIColorCube", parameters: [
                "inputCubeDimension": 32,
                "inputCubeData": selectiveColorCube(settings),
            ])
            image = try render(adjusted.cropped(to: extent), job: job)
        case .replaceColor:
            guard settings.replaceTolerance > 0 else { image = job.image; break }
            let adjusted = edges.applyingFilter("CIColorCube", parameters: [
                "inputCubeDimension": 32,
                "inputCubeData": replaceColorCube(settings),
            ])
            image = try render(adjusted.cropped(to: extent), job: job)
        case .vibrance:
            guard settings.vibranceAmount != 0 else { image = job.image; break }
            let adjusted = edges.applyingFilter("CIVibrance", parameters: [kCIInputAmountKey: settings.vibranceAmount / 100])
            image = try render(adjusted.cropped(to: extent), job: job)
        case .posterize:
            let posterized = edges.applyingFilter("CIColorPosterize", parameters: ["inputLevels": settings.posterizeLevels])
            image = try render(posterized.cropped(to: extent), job: job)
        case .threshold:
            // Luminosity, as Photoshop measures it: a plain desaturation, then one split through white.
            let gray = edges.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            let split = gray.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": settings.thresholdLevel / 255])
            image = try render(split.cropped(to: extent), job: job)
        case .mosaic:
            let blocks = edges.applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: settings.mosaicCellSize * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(blocks.cropped(to: extent), job: job)
        case .crystallize:
            let crystals = edges.applyingFilter("CICrystallize", parameters: [
                kCIInputRadiusKey: settings.crystallizeSize * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(crystals.cropped(to: extent), job: job)
        case .colorHalftone:
            let halftone = edges.applyingFilter("CICMYKHalftone", parameters: [
                "inputWidth": settings.halftoneWidth * job.scale,
                "inputAngle": settings.halftoneAngle * .pi / 180,
                "inputSharpness": settings.halftoneSharpness / 100,
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(halftone.cropped(to: extent), job: job)
        case .twirl:
            let radius = hypot(extent.width, extent.height) / 2
            let twirled = edges.applyingFilter("CITwirlDistortion", parameters: [
                kCIInputAngleKey: settings.twirlAngle * .pi / 180,
                kCIInputRadiusKey: radius,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(twirled.cropped(to: extent), job: job)
        case .pinch:
            let radius = hypot(extent.width, extent.height) / 2
            let pinched = edges.applyingFilter("CIPinchDistortion", parameters: [
                kCIInputScaleKey: settings.pinchAmount / 100,
                kCIInputRadiusKey: radius,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(pinched.cropped(to: extent), job: job)
        case .spherize:
            let radius = hypot(extent.width, extent.height) / 2
            let sphere = edges.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputScaleKey: settings.spherizeAmount / 100 * 0.9,
                kCIInputRadiusKey: radius,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(sphere.cropped(to: extent), job: job)
        case .vortex:
            let radius = hypot(extent.width, extent.height) / 2
            let swirled = edges.applyingFilter("CIVortexDistortion", parameters: [
                kCIInputAngleKey: settings.vortexAngle * .pi / 180,
                kCIInputRadiusKey: radius,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(swirled.cropped(to: extent), job: job)
        case .gloom:
            let glowed = edges.applyingFilter("CIGloom", parameters: [
                kCIInputRadiusKey: settings.gloomRadius * job.scale,
                kCIInputIntensityKey: settings.gloomIntensity / 100,
            ])
            image = try render(glowed.cropped(to: extent), job: job)
        case .kaleidoscope:
            let mirror = edges.applyingFilter("CIKaleidoscope", parameters: [
                "inputCount": settings.kaleidoscopeCount,
                "inputAngle": settings.kaleidoscopeAngle * .pi / 180,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(mirror.cropped(to: extent), job: job)
        case .findEdges:
            let outline = edges.applyingFilter("CIEdges", parameters: ["inputIntensity": settings.edgesIntensity])
            image = try render(outline.applyingFilter("CIColorInvert").cropped(to: extent), job: job)
        case .comic:
            image = try render(edges.applyingFilter("CIComicEffect").cropped(to: extent), job: job)
        case .lineScreen:
            let screened = edges.applyingFilter("CILineScreen", parameters: [
                "inputWidth": settings.halftoneWidth * job.scale,
                "inputAngle": settings.halftoneAngle * .pi / 180,
                "inputSharpness": settings.halftoneSharpness / 100,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(screened.cropped(to: extent), job: job)
        case .circularScreen:
            let screened = edges.applyingFilter("CICircularScreen", parameters: [
                "inputWidth": settings.halftoneWidth * job.scale,
                "inputSharpness": settings.halftoneSharpness / 100,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(screened.cropped(to: extent), job: job)
        case .hatchedScreen:
            let screened = edges.applyingFilter("CIHatchedScreen", parameters: [
                "inputWidth": settings.halftoneWidth * job.scale,
                "inputAngle": settings.halftoneAngle * .pi / 180,
                "inputSharpness": settings.halftoneSharpness / 100,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(screened.cropped(to: extent), job: job)
        case .glass:
            guard let texture = CIFilter(name: "CIRandomGenerator")?.outputImage?
                .cropped(to: extent.insetBy(dx: -extent.width, dy: -extent.height)) else { throw ExportError.render }
            let warped = edges.clampedToExtent().applyingFilter("CIGlassDistortion", parameters: [
                "inputTexture": texture,
                "inputScale": settings.glassScale * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(warped.cropped(to: extent), job: job)
        case .glassLozenge:
            let warped = edges.clampedToExtent().applyingFilter("CIGlassLozenge", parameters: [
                "inputPoint0": CIVector(x: extent.midX - extent.width * 0.15, y: extent.midY),
                "inputPoint1": CIVector(x: extent.midX + extent.width * 0.15, y: extent.midY),
                "inputRadius": settings.glassLensRadius * job.scale,
                "inputRefraction": settings.glassRefraction,
            ])
            image = try render(warped.cropped(to: extent), job: job)
        case .triangleKaleidoscope:
            let mirrored = edges.applyingFilter("CITriangleKaleidoscope", parameters: [
                "inputPoint": CIVector(x: extent.midX, y: extent.midY),
                "inputSize": settings.triangleKaleidoscopeSize * job.scale,
                "inputRotation": settings.triangleKaleidoscopeRotation * .pi / 180,
                "inputDecay": settings.triangleKaleidoscopeDecay,
            ])
            image = try render(mirrored.cropped(to: extent), job: job)
        case .falseColor:
            let dark = settings.falseColorPalette.dark, light = settings.falseColorPalette.light
            let mapped = edges.applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor(red: dark.red, green: dark.green, blue: dark.blue),
                "inputColor1": CIColor(red: light.red, green: light.green, blue: light.blue),
            ])
            image = try render(mapped.cropped(to: extent), job: job)
        case .monochrome:
            let tint = settings.monochromeTint.color
            let toned = edges.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: tint.red, green: tint.green, blue: tint.blue),
                kCIInputIntensityKey: settings.monochromeAmount / 100,
            ])
            image = try render(toned.cropped(to: extent), job: job)
        case .discBlur:
            let blurred = edges.clampedToExtent().applyingFilter("CIDiscBlur", parameters: [
                kCIInputRadiusKey: settings.discBlurRadius * job.scale,
            ])
            image = try render(blurred.cropped(to: extent), job: job)
        case .lensFlare:
            guard settings.lensFlareBrightness > 0 else { image = job.image; break }
            let point = settings.lensFlarePosition.point(in: extent)
            let tint = settings.lensFlareTint.color
            let strength = min(1, settings.lensFlareBrightness / 100)
            let color = CIColor(red: tint.red * strength, green: tint.green * strength, blue: tint.blue * strength)
            let center = CIVector(x: point.x, y: point.y)
            let size = settings.lensFlareSize * job.scale
            guard let sun = CIFilter(name: "CISunbeamsGenerator", parameters: [
                    kCIInputCenterKey: center, kCIInputColorKey: color,
                    "inputSunRadius": size * 0.08, "inputMaxStriationRadius": size * 0.04,
                    "inputStriationStrength": 0.5, "inputStriationContrast": 1,
                ])?.outputImage,
                let halo = CIFilter(name: "CILenticularHaloGenerator", parameters: [
                    kCIInputCenterKey: center, kCIInputColorKey: color,
                    "inputHaloRadius": size * 0.25, "inputHaloWidth": size * 0.12, "inputHaloOverlap": 0.8,
                ])?.outputImage,
                let star = CIFilter(name: "CIStarShineGenerator", parameters: [
                    kCIInputCenterKey: center, kCIInputColorKey: color,
                    "inputRadius": size * 0.06, "inputCrossScale": 15, "inputCrossWidth": 2.5, "inputEpsilon": 1.5,
                ])?.outputImage else { throw ExportError.render }
            let glow = halo.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: sun])
                .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: star])
            let lit = glow.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: edges])
            image = try render(lit.cropped(to: extent), job: job)
        case .lightTunnel:
            let tunnel = edges.applyingFilter("CILightTunnel", parameters: [
                kCIInputRadiusKey: settings.lightTunnelRadius * job.scale,
                "inputRotation": settings.lightTunnelRotation * .pi / 180,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(tunnel.cropped(to: extent), job: job)
        case .solarize:
            let threshold = settings.solarizeThreshold
            let table = (0...255).map { index -> Float in
                let value = Double(index)
                return Float((value <= threshold ? value : 255 - value) / 255)
            }
            let solarized = edges.applyingFilter("CIColorCurves", parameters: curveParameters([table]))
            image = try render(solarized.cropped(to: extent), job: job)
        case .clouds, .differenceClouds:
            let clouds = try cloudImage(width: width, height: height, job: job, settings: settings)
            guard job.kind == .differenceClouds else { image = clouds; break }
            let blended = CIImage(cgImage: clouds).applyingFilter("CIDifferenceBlendMode", parameters: [
                kCIInputBackgroundImageKey: edges,
            ])
            image = try render(blended.cropped(to: extent), job: job)
        case .offset:
            let dx = settings.offsetX * job.scale, dy = -settings.offsetY * job.scale
            let moved = edges.transformed(by: CGAffineTransform(translationX: dx, y: dy))
            guard settings.offsetWrap else {
                image = try render(moved.cropped(to: extent), job: job)
                break
            }
            var wrapped: CIImage?
            for column in -1...1 {
                for row in -1...1 {
                    let copy = moved.transformed(by: CGAffineTransform(
                        translationX: extent.width * CGFloat(column), y: extent.height * CGFloat(row)))
                    wrapped = wrapped.map {
                        copy.applyingFilter("CISourceOverCompositing", parameters: [kCIInputBackgroundImageKey: $0])
                    } ?? copy
                }
            }
            guard let wrapped else { throw ExportError.render }
            image = try render(wrapped.cropped(to: extent), job: job)
        case .tiltShiftBlur:
            let blurred = extending(edges, past: job.canvasSides, of: extent)
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: settings.tiltShiftRadius * job.scale])
            let angle = settings.tiltShiftAngle * .pi / 180
            let normal = CGPoint(x: sin(angle), y: cos(angle))
            let focus = CGPoint(x: extent.midX + normal.x * (settings.tiltShiftFocus / 100 - 0.5) * extent.height,
                                y: extent.midY + normal.y * (settings.tiltShiftFocus / 100 - 0.5) * extent.height)
            let halfBand = settings.tiltShiftBand / 100 * extent.height / 2
            let reach = (max(extent.width, extent.height) + halfBand) * 1.5
            func gradient(_ toward: CGFloat) -> CIImage? {
                let start = CGPoint(x: focus.x + normal.x * halfBand * toward, y: focus.y + normal.y * halfBand * toward)
                let end = CGPoint(x: focus.x + normal.x * (halfBand + reach) * toward,
                                  y: focus.y + normal.y * (halfBand + reach) * toward)
                return CIFilter(name: "CILinearGradient", parameters: [
                    "inputPoint0": CIVector(x: start.x, y: start.y),
                    "inputPoint1": CIVector(x: end.x, y: end.y),
                    "inputColor0": CIColor(red: 0, green: 0, blue: 0),
                    "inputColor1": CIColor(red: 1, green: 1, blue: 1),
                ])?.outputImage
            }
            guard let above = gradient(1), let below = gradient(-1) else { throw ExportError.render }
            let mask = above.applyingFilter("CILightenBlendMode", parameters: [kCIInputBackgroundImageKey: below]).cropped(to: extent)
            let mixed = blurred.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: edges,
                kCIInputMaskImageKey: mask,
            ])
            image = try render(mixed.cropped(to: extent), job: job)
        case .irisBlur:
            let blurred = extending(edges, past: job.canvasSides, of: extent)
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: settings.irisBlurRadius * job.scale])
            let radius = settings.irisRadius * job.scale
            let feather = max(1, settings.irisFeather / 100 * radius)
            guard let mask = CIFilter(name: "CIRadialGradient", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                "inputRadius0": radius,
                "inputRadius1": radius + feather,
                "inputColor0": CIColor(red: 0, green: 0, blue: 0),
                "inputColor1": CIColor(red: 1, green: 1, blue: 1),
            ])?.outputImage?.cropped(to: extent) else { throw ExportError.render }
            let mixed = blurred.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: edges,
                kCIInputMaskImageKey: mask,
            ])
            image = try render(mixed.cropped(to: extent), job: job)
        case .boxBlur:
            let source = extending(edges, past: job.canvasSides, of: extent)
            let blurred = source.applyingFilter("CIBoxBlur", parameters: [kCIInputRadiusKey: settings.boxBlurRadius * job.scale])
            image = try render(blurred.cropped(to: extent), job: job)
        case .zoomBlur:
            let zoomed = edges.applyingFilter("CIZoomBlur", parameters: [
                kCIInputAmountKey: settings.zoomAmount * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(zoomed.cropped(to: extent), job: job)
        case .bokehBlur:
            let bokeh = edges.applyingFilter("CIBokehBlur", parameters: [
                kCIInputRadiusKey: settings.bokehRadius * job.scale,
                "inputRingAmount": settings.bokehRingAmount / 100,
                "inputRingSize": settings.bokehRingSize / 100,
                "inputSoftness": settings.bokehSoftness / 100,
            ])
            image = try render(bokeh.cropped(to: extent), job: job)
        case .median:
            image = try render(edges.applyingFilter("CIMedianFilter").cropped(to: extent), job: job)
        case .photoEffect:
            image = try render(edges.applyingFilter(settings.photoEffect.filterName).cropped(to: extent), job: job)
        case .shadowsHighlights:
            let tone = settings.shadowsHighlights
            guard !tone.isIdentity else { image = job.image; break }
            let adjusted = edges.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": tone.shadows / 100,
                "inputHighlightAmount": tone.highlights / 100,
                kCIInputRadiusKey: tone.radius * job.scale,
            ])
            image = try render(adjusted.cropped(to: extent), job: job)
        case .pointillize:
            let dots = edges.applyingFilter("CIPointillize", parameters: [
                kCIInputRadiusKey: settings.pointillizeSize * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(dots.cropped(to: extent), job: job)
        case .hexagonalPixelate:
            let hexagons = edges.applyingFilter("CIHexagonalPixellate", parameters: [
                kCIInputScaleKey: settings.hexagonalPixelateSize * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(hexagons.cropped(to: extent), job: job)
        case .hole:
            let holed = edges.applyingFilter("CIHoleDistortion", parameters: [
                kCIInputRadiusKey: settings.holeRadius * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(holed.cropped(to: extent), job: job)
        case .circleSplash:
            let splashed = edges.applyingFilter("CICircleSplashDistortion", parameters: [
                kCIInputRadiusKey: settings.circleSplashRadius * job.scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(splashed.cropped(to: extent), job: job)
        case .torusLens:
            let lens = edges.applyingFilter("CITorusLensDistortion", parameters: [
                kCIInputRadiusKey: settings.torusLensRadius * job.scale,
                "inputWidth": settings.torusLensWidth * job.scale,
                "inputRefraction": settings.torusLensRefraction,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ])
            image = try render(lens.cropped(to: extent), job: job)
        case .desaturate:
            let gray = edges.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            image = try render(gray.cropped(to: extent), job: job)
        case .autoTone, .autoContrast, .autoColor, .equalize:
            image = try render(autoAdjusted(edges, source: job.image, kind: job.kind).cropped(to: extent), job: job)
        }
        guard let selection = job.selection else { return image }
        return try PixelAdjust.blend(image, over: job.image, through: selection, pixelToDocument: job.mapping, isMask: false,
                                     sixteenBit: job.sixteenBit)
    }

    /// A small RGBA copy of an image, for reading its histogram without touching every full-size pixel.
    private struct HistogramSample {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let rowBytes: Int
    }

    private static func histogramSample(_ image: CGImage) throws -> HistogramSample {
        let longest = max(image.width, image.height)
        let scale = longest > 512 ? 512 / CGFloat(longest) : 1
        let width = max(1, Int(CGFloat(image.width) * scale)), height = max(1, Int(CGFloat(image.height) * scale))
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        BrushRaster.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height), mask: false, context: context)
        guard let data = context.data else { throw ExportError.render }
        let count = context.bytesPerRow * height
        return HistogramSample(pixels: Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count)),
                               width: width, height: height, rowBytes: context.bytesPerRow)
    }

    /// Auto Tone, Auto Contrast, Auto Color and Equalize, as curves through the picture's own histogram.
    private static func autoAdjusted(_ image: CIImage, source: CGImage, kind: FilterKind) throws -> CIImage {
        let sample = try histogramSample(source)
        var channels = [[Int]](repeating: [Int](repeating: 0, count: 256), count: 3)
        var luminance = [Int](repeating: 0, count: 256)
        var counted = 0
        for y in 0..<sample.height {
            for x in 0..<sample.width {
                let offset = y * sample.rowBytes + x * 4
                guard sample.pixels[offset + 3] > 8 else { continue }
                let red = Int(sample.pixels[offset]), green = Int(sample.pixels[offset + 1]), blue = Int(sample.pixels[offset + 2])
                channels[0][red] += 1
                channels[1][green] += 1
                channels[2][blue] += 1
                luminance[Int(0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue))] += 1
                counted += 1
            }
        }
        guard counted > 0 else { return image }
        let tables: [[Float]]
        switch kind {
        case .autoContrast:
            let range = percentileRange(luminance, total: counted, low: 0.005, high: 0.995)
            let table = stretchedTable(low: range.low, high: range.high)
            tables = [table, table, table]
        case .autoTone, .autoColor:
            tables = channels.map { histogram in
                let range = percentileRange(histogram, total: counted, low: 0.005, high: 0.995)
                return stretchedTable(low: range.low, high: range.high)
            }
        case .equalize:
            tables = channels.map { equalizedTable($0, total: counted) }
        default:
            return image
        }
        return image.applyingFilter("CIColorCurves", parameters: curveParameters(tables))
    }

    private static func percentileRange(_ histogram: [Int], total: Int, low: Double, high: Double)
        -> (low: Double, high: Double) {
        let lowTarget = max(1, Int(Double(total) * low))
        let highTarget = max(lowTarget + 1, Int(Double(total) * high))
        var cumulative = 0, lowLevel = 0, highLevel = 255
        for level in 0..<256 {
            cumulative += histogram[level]
            if cumulative >= lowTarget { lowLevel = level; break }
        }
        cumulative = 0
        for level in 0..<256 {
            cumulative += histogram[level]
            if cumulative >= highTarget { highLevel = level; break }
        }
        // A picture already spanning almost nothing has no contrast to stretch.
        guard highLevel - lowLevel >= 2 else { return (0, 1) }
        return (Double(lowLevel) / 255, Double(highLevel) / 255)
    }

    private static func stretchedTable(low: Double, high: Double) -> [Float] {
        let span = max(1.0 / 255, high - low)
        return (0...255).map { level in
            Float(min(1, max(0, (Double(level) / 255 - low) / span)))
        }
    }

    private static func equalizedTable(_ histogram: [Int], total: Int) -> [Float] {
        var cumulative = 0
        var values = [Int](repeating: 0, count: 256)
        var first = 0
        for level in 0..<256 {
            cumulative += histogram[level]
            if first == 0, cumulative > 0 { first = cumulative }
            values[level] = cumulative
        }
        let span = max(1, total - first)
        return (0..<256).map { level in
            Float(min(1, max(0, Double(values[level] - first) / Double(span))))
        }
    }

    /// A color cube of `dimension` steps a channel, each sample passed through `transform`, clamped to the cube.
    private static func colorCube(dimension: Int = 32,
                                  _ transform: (Double, Double, Double) -> (Double, Double, Double)) -> Data {
        var cube = [Float](repeating: 0, count: dimension * dimension * dimension * 4)
        let step = 1 / Double(dimension - 1)
        var index = 0
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let (outRed, outGreen, outBlue) = transform(Double(red) * step, Double(green) * step, Double(blue) * step)
                    cube[index] = Float(min(1, max(0, outRed)))
                    cube[index + 1] = Float(min(1, max(0, outGreen)))
                    cube[index + 2] = Float(min(1, max(0, outBlue)))
                    cube[index + 3] = 1
                    index += 4
                }
            }
        }
        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func hsv(_ red: Double, _ green: Double, _ blue: Double) -> (hue: Double, saturation: Double, value: Double) {
        let high = max(red, green, blue), low = min(red, green, blue), delta = high - low
        var hue = 0.0
        if delta > 0 {
            if high == red {
                hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if high == green {
                hue = 60 * ((blue - red) / delta + 2)
            } else {
                hue = 60 * ((red - green) / delta + 4)
            }
        }
        if hue < 0 { hue += 360 }
        return (hue, high == 0 ? 0 : delta / high, high)
    }

    private static func rgb(hue: Double, saturation: Double, value: Double) -> (red: Double, green: Double, blue: Double) {
        let chroma = value * saturation
        let section = (hue / 60).truncatingRemainder(dividingBy: 6)
        let second = chroma * (1 - abs(section.truncatingRemainder(dividingBy: 2) - 1))
        let match = value - chroma
        let (red, green, blue): (Double, Double, Double)
        switch section {
        case 0..<1: (red, green, blue) = (chroma, second, 0)
        case 1..<2: (red, green, blue) = (second, chroma, 0)
        case 2..<3: (red, green, blue) = (0, chroma, second)
        case 3..<4: (red, green, blue) = (0, second, chroma)
        case 4..<5: (red, green, blue) = (second, 0, chroma)
        default: (red, green, blue) = (chroma, 0, second)
        }
        return (red + match, green + match, blue + match)
    }

    private static func hueDistance(_ one: Double, _ other: Double) -> Double {
        let distance = abs(one - other).truncatingRemainder(dividingBy: 360)
        return min(distance, 360 - distance)
    }

    private static func hueDelta(from start: Double, to end: Double) -> Double {
        var delta = (end - start).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private static func selectiveColorCube(_ settings: FilterSettings) -> Data {
        let families = SelectiveColorFamily.allCases
        let amounts = settings.selectiveAmounts
        return colorCube { red, green, blue in
            let (hue, saturation, value) = hsv(red, green, blue)
            var weights = [Double](repeating: 0, count: families.count)
            if saturation > 0.02 {
                for (index, family) in families.enumerated() {
                    guard let middle = family.hue else { continue }
                    weights[index] = max(0, 1 - hueDistance(hue, middle) / 60) * min(1, saturation * 3)
                }
            }
            let grayness = max(0, 1 - saturation / 0.25)
            if grayness > 0 {
                let white = grayness * min(1, max(0, (value - 0.55) / 0.45))
                let black = grayness * min(1, max(0, (0.45 - value) / 0.45))
                let neutral = max(0, grayness - white - black)
                if let index = families.firstIndex(of: .whites) { weights[index] = white }
                if let index = families.firstIndex(of: .neutrals) { weights[index] = neutral }
                if let index = families.firstIndex(of: .blacks) { weights[index] = black }
            }
            var outRed = red, outGreen = green, outBlue = blue
            for (index, ink) in amounts.enumerated() where !ink.isIdentity {
                let weight = weights[index]
                guard weight > 0 else { continue }
                outRed -= ink.cyan / 100 * weight
                outGreen -= ink.magenta / 100 * weight
                outBlue -= ink.yellow / 100 * weight
                let darken = max(0, 1 - ink.black / 100 * weight)
                outRed *= darken
                outGreen *= darken
                outBlue *= darken
            }
            return (outRed, outGreen, outBlue)
        }
    }

    private static func replaceColorCube(_ settings: FilterSettings) -> Data {
        let target = ((settings.replaceTargetHue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let tolerance = settings.replaceTolerance
        let destination = settings.replaceHue
        return colorCube { red, green, blue in
            let (hue, saturation, value) = hsv(red, green, blue)
            guard saturation > 0.05, tolerance > 0 else { return (red, green, blue) }
            let weight = max(0, 1 - hueDistance(hue, target) / tolerance)
            guard weight > 0 else { return (red, green, blue) }
            let movedHue = hue + hueDelta(from: target, to: destination) * weight
            let movedSaturation = min(1, max(0, saturation + settings.replaceSaturation / 100 * weight))
            let movedValue = min(1, max(0, value + settings.replaceLightness / 100 * weight))
            let (newRed, newGreen, newBlue) = rgb(hue: movedHue, saturation: movedSaturation, value: movedValue)
            return (red + (newRed - red) * weight, green + (newGreen - green) * weight, blue + (newBlue - blue) * weight)
        }
    }

    /// How much Motion Blur's kernel scales alpha down, as the factor that puts it back: measured on a white
    /// image at the same radius and angle, so an opaque picture stays fully opaque.
    private static func motionBlurAlphaGain(radius: CGFloat, angle: CGFloat) -> CGFloat {
        let probe = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).clampedToExtent()
        let blurred = probe.applyingFilter("CIMotionBlur", parameters: [
            kCIInputRadiusKey: radius,
            kCIInputAngleKey: angle,
        ])
        var pixel = [UInt8](repeating: 0, count: 4)
        PixelAdjust.ciContext.render(blurred, toBitmap: &pixel, rowBytes: 4,
                                     bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8,
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        let alpha = CGFloat(pixel[3]) / 255
        return alpha > 0.5 ? 1 / alpha : 1
    }

    /// Clouds: opaque fractal noise colored between the style's dark and light, at the job's pixels.
    private static func cloudImage(width: Int, height: Int, job: FilterJob, settings: FilterSettings) throws -> CGImage {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        guard let data = context.data else { throw ExportError.render }
        noise_clouds(data.assumingMemoryBound(to: UInt8.self), width, height, context.bytesPerRow,
                     Float(settings.cloudsScale * job.scale), Float(settings.cloudsDetail), settings.cloudsSeed)
        guard let gray = context.makeImage() else { throw ExportError.render }
        let dark = settings.cloudsStyle.dark, light = settings.cloudsStyle.light
        let colored = CIImage(cgImage: gray).applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: light.red - dark.red, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: light.green - dark.green, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: light.blue - dark.blue, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: dark.red, y: dark.green, z: dark.blue, w: 1),
        ])
        return try render(colored, job: job)
    }

    private static func curveParameters(_ tables: [[Float]]) -> [String: Any] {
        var data = [Float]()
        data.reserveCapacity(768)
        // CIColorCurves reads one RGB triple for each input level: red, green and blue curves interleaved.
        for index in 0..<256 {
            for channel in 0..<3 {
                data.append(tables.indices.contains(channel) ? tables[channel][index] : tables[0][index])
            }
        }
        return [
            "inputCurvesData": data.withUnsafeBufferPointer { Data(buffer: $0) },
            "inputCurvesDomain": CIVector(x: 0, y: 1),
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!,
        ]
    }

    /// A filter's preview on an HDR layer's pixels (`hdr`, at the preview's size), made the way OK makes the result: the
    /// Core Image filters on them as they are, Exposure exactly, the rest with highlights divided down to within white
    /// and multiplied back (`DeepLayer.normalizing`) — run once here, where OK runs them several times and reads
    /// between, too slow for every slider move and too fine to see.
    static func previewHDR(_ job: FilterJob, from hdr: CGImage) throws -> CGImage {
        // As `run`: the job carries the whole FilterSettings, and a concurrency thread's stack is too small for a copy
        // of it plus the Core Image work below.
        try BigStack.run { try previewHDRBody(job, from: hdr) }
    }

    private static func previewHDRBody(_ job: FilterJob, from hdr: CGImage) throws -> CGImage {
        var run = job
        run.image = hdr
        if job.kind.runsAtSixteenBits {
            run.sixteenBit = true
            return try PixelFilter.run(run)
        }
        if job.kind == .exposure {
            let result = try DeepLayer.exposure(hdr, job.settings.exposure)
            guard let selection = job.selection else { return result }
            return try PixelAdjust.blend(result, over: hdr, through: selection, pixelToDocument: job.mapping, isMask: false, sixteenBit: true)
        }
        return try DeepLayer.normalizing(hdr) { normal in
            run.image = normal
            return try PixelFilter.run(run)
        }
    }

    /// Progressive Blur: sharp at the start of its line, blurring to the full amount at the end (or, radial, outwards from
    /// the start to the circle through the end), by a mask Core Image blurs through. Past the canvas's edge the layer's
    /// edge pixels carry on, as Gaussian Blur's do.
    static func progressivelyBlurred(_ edges: CIImage, job: FilterJob, settings: FilterSettings, extent: CGRect) -> CIImage {
        // The line in the image's pixels, then in Core Image's, whose y axis points up.
        let toPixels = job.mapping.inverted()
        func point(_ document: CGPoint) -> CGPoint {
            let pixel = document.applying(toPixels)
            return CGPoint(x: pixel.x, y: extent.height - pixel.y)
        }
        let start = point(settings.progressiveStart ?? CGPoint(x: extent.midX, y: extent.minY).applying(job.mapping))
        var end = point(settings.progressiveEnd ?? CGPoint(x: extent.midX, y: extent.maxY).applying(job.mapping))
        if hypot(end.x - start.x, end.y - start.y) < 1 { end = CGPoint(x: start.x, y: start.y - 1) }
        // The mask gives each place its share of the strongest blur: From's at the start, To's at the end.
        var from = settings.progressiveFrom, to = settings.progressiveTo
        if settings.progressiveInverted { swap(&from, &to) }
        let strongest = max(from, to)
        guard strongest > 0 else { return edges }
        func share(_ radius: Double) -> CIColor { CIColor(red: radius / strongest, green: radius / strongest, blue: radius / strongest) }
        let mask = settings.progressiveRadial
            ? CIFilter(name: "CIRadialGradient", parameters: [
                kCIInputCenterKey: CIVector(cgPoint: start), "inputRadius0": 0,
                "inputRadius1": hypot(end.x - start.x, end.y - start.y), "inputColor0": share(from), "inputColor1": share(to)])!.outputImage!
            : CIFilter(name: "CILinearGradient", parameters: [
                "inputPoint0": CIVector(cgPoint: start), "inputPoint1": CIVector(cgPoint: end),
                "inputColor0": share(from), "inputColor1": share(to)])!.outputImage!
        return extending(edges, past: job.canvasSides, of: extent).applyingFilter("CIMaskedVariableBlur", parameters: [
            "inputMask": mask, kCIInputRadiusKey: strongest * job.scale,
        ])
    }

    /// A Core Image filter's result, at 16 bits for a 16-bit layer's pixels.
    private static func render(_ image: CIImage, job: FilterJob) throws -> CGImage {
        let width = job.image.width, height = job.image.height
        if job.sixteenBit { return try DeepLayer.render(image, width: width, height: height, hdr: DeepLayer.isHDR(job.image)) }
        return try PixelAdjust.render(image, width: width, height: height, isMask: false)
    }
}

@Observable
final class FilterEdit {
    let kind: FilterKind
    /// Filter › Last Filter, applied straight away with the settings it had.
    var repeating = false
    let layerID: UUID
    let original: ImportedImage
    let transform: LayerTransform
    let selection: SelectionClip?
    var mapping: CGAffineTransform
    var previewSource: CGImage
    /// An HDR layer's pixels at the preview's size and grid, which its preview is made from, as OK makes the result from
    /// the layer's own: from `previewSource`, clipped to white, a blur or Exposure would preview something else.
    var hdrPreviewSource: CGImage?
    var previewScale: CGFloat
    var previewMapping: CGAffineTransform
    /// A filter reaching past the layer's edge — Content-Aware Fill over a selection, a blur spreading outwards —
    /// works on the layer's pixels padded out, and on the transform placing that larger grid.
    var grownImage: CGImage? = nil
    var grownTransform: LayerTransform? = nil
    /// Where the layer's own pixels sit within `grownImage`, so a 16-bit layer's pixels can be padded the same way.
    var grownInside: CGRect? = nil
    /// How far the padding reaches beyond the layer on every side, in layer pixels.
    var grownMargin: CGFloat = 0
    /// The layer's sides at or past the canvas's edge, where Gaussian and Motion Blur carry its edge pixels on rather
    /// than spreading into clear ones: they're given no padding.
    private(set) var canvasSides: LayerSides = []
    var settings: FilterSettings
    var preview = true
    var committing = false
    var previewError: String?
    var preparing = false
    /// Add Noise's grain, fixed while the panel is open so changing Amount doesn't reshuffle it.
    let seed = UInt32.random(in: .min ... .max)
    /// Camera Raw panel eyes. Off drops that group's amounts from the preview and from OK, without clearing the sliders.
    var showsCameraRawLight = true
    var showsCameraRawColor = true
    var showsCameraRawEffects = true
    var showsCameraRawCurve = true
    var showsCameraRawMixer = true
    var showsCameraRawGrading = true
    var showsCameraRawDetail = true
    var showsCameraRawOptics = true
    var showsCameraRawGeometry = true
    var showsCameraRawCalibration = true
    var cameraRawCurvePage: CameraRawCurvePage = .parametric
    var cameraRawPointChannel: CameraRawPointChannel = .rgb
    var cameraRawMixerPage: CameraRawMixerPage = .hsl
    var cameraRawMixerTab: CameraRawMixerTab = .hue
    var cameraRawMixerSwatch = 0
    var cameraRawPointIndex = 0
    var cameraRawGradePage: CameraRawGradePage = .threeWay
    var targetsCameraRawCurve = false
    var targetsCameraRawMixer = false
    var samplesPointColor = false
    var cameraRawDrag: CameraRawDrag?
    var pointColorVisualizeIndex: Int {
        let points = settings.cameraRaw.mixer.points
        guard points.indices.contains(cameraRawPointIndex), points[cameraRawPointIndex].visualize else { return -1 }
        return cameraRawPointIndex
    }
    /// White-balance eyedropper, armed from the Color section.
    var samplesWhiteBalance = false
    /// Defringe eyedropper, armed from Optics. Sets purple or green hue range from the clicked fringe.
    var samplesDefringe = false
    /// Guided Upright: drag lines on the preview.
    var drawingCameraRawGeometryGuide = false
    var cameraRawGuideDraft: (start: CGPoint, end: CGPoint)?
    /// Set while Option is held on Exposure, Highlights, Shadows, Whites, or Blacks.
    var cameraRawClipping: CameraRawClipping?
    /// Set while Option is held on Sharpening Masking.
    var cameraRawSharpenMask = false
    /// Histogram clipping indicators. They paint the preview and are not baked in on OK.
    var showsShadowClipping = false
    var showsHighlightClipping = false
    /// Histogram, or the vectorscope chosen from its context menu.
    var cameraRawScopeMode: CameraRawScopeMode = .histogram
    var cameraRawScope: CameraRawScope?
    /// RGB of the pixel under the pointer, in the adjusted preview.
    var cameraRawReadout: (red: Int, green: Int, blue: Int)?
    /// Vignette on an empty layer: the canvas it frames and fills.
    @ObservationIgnored var canvas: CGRect?
    /// The layer had no pixels yet (an empty layer); the filter started it from clear ones.
    @ObservationIgnored var startedEmpty = false
    @ObservationIgnored var preparedPreview: CGImage?
    /// Where `preparedPreview` goes: the grown layer it was made from, or nil for the layer's own place. A blur grows
    /// the layer as it gets bigger; the last preview stays up where it belongs until the next one replaces it.
    @ObservationIgnored var preparedTransform: LayerTransform?
    /// The grown layer `pending` is made from.
    @ObservationIgnored var pendingTransform: LayerTransform?
    /// Reject a render started before the blur's padded pixel grid changed.
    @ObservationIgnored var previewSourceVersion: UInt64 = 0
    /// Camera Raw's adaptive sliders read the picture before any change, which stays the same while the panel is open:
    /// measured once from the preview's source, again only when that changes.
    @ObservationIgnored private var cameraRawBrightness: (version: UInt64, value: CameraRawTables.Brightness)?
    var previewBrightness: CameraRawTables.Brightness? {
        guard let cached = cameraRawBrightness, cached.version == previewSourceVersion else { return nil }
        return cached.value
    }
    func cachePreviewBrightness(_ value: CameraRawTables.Brightness) {
        cameraRawBrightness = (previewSourceVersion, value)
    }
    /// The settings `preparedPreview` was made with, for the automatic filters that have settings of their own.
    @ObservationIgnored var preparedSettings: FilterSettings?
    @ObservationIgnored var pending: FilterJob?
    @ObservationIgnored var previewTask: Task<Void, Never>?
    /// Volumetric Light's first preview, held for the depth model (`beginFilter`).
    @ObservationIgnored var waitsForDepth = false
    /// Previews render from a copy no larger than this on its longest side.
    static let previewLimit: CGFloat = 2048

    /// `growingTo`: a document area the layer's grid should cover (Content-Aware Fill's selection on the canvas).
    /// A blur grows the grid by its own reach instead, and again if its amount is raised.
    init(kind: FilterKind, layer: ImageLayer, selection: SelectionClip?, settings: FilterSettings, growingTo area: CGRect? = nil,
         canvas: CGSize? = nil) throws {
        guard let asset = layer.asset else { throw ProjectError.invalid }
        self.kind = kind
        self.settings = settings.normalized
        layerID = layer.id; original = asset; transform = layer.transform; self.selection = selection
        let ready = try Self.prepared(kind: kind, from: asset.image, placed: layer.transform)
        mapping = ready.mapping
        previewSource = ready.previewSource
        previewScale = ready.previewScale
        previewMapping = ready.previewMapping
        hdrPreviewSource = try Self.hdrPreview(of: asset, inside: nil, grid: nil, size: ready.previewSource)
        // A rotated layer's sides don't run along the canvas's, so it has none at its edge.
        if let canvas, kind == .gaussianBlur || kind == .motionBlur || kind == .progressiveBlur, layer.transform.rotation == 0 {
            let inPixels = CGRect(origin: .zero, size: canvas).applying(ready.mapping.inverted())
            let width = CGFloat(asset.image.width), height = CGFloat(asset.image.height)
            if inPixels.minX >= -0.5 { canvasSides.insert(.left) }
            if inPixels.maxX <= width + 0.5 { canvasSides.insert(.right) }
            if inPixels.minY >= -0.5 { canvasSides.insert(.top) }
            if inPixels.maxY <= height + 0.5 { canvasSides.insert(.bottom) }
        }
        if let area {
            let toPixels = BrushRaster.pixelToDocument(layer.transform, width: asset.image.width, height: asset.image.height).inverted()
            try grow(to: area.applying(toPixels).integral)
        }
        try growForBlur()
    }

    /// The room a blur needs around the layer: about three standard deviations, or half a streak.
    static func blurMargin(_ kind: FilterKind, _ settings: FilterSettings) -> CGFloat {
        switch kind {
        case .gaussianBlur: return settings.preserveTransparency ? 0 : CGFloat(settings.radius * 3 + 2)
        case .motionBlur: return CGFloat(settings.distance / 2 + 2)
        // Radial reaches farther than its distance past `rgbSplitReach` from the center.
        case .rgbSplit: return CGFloat((settings.rgbSplitDistance + settings.rgbSplitBlur) * (settings.rgbSplitRadial ? 2 : 1) + 2)
        case .progressiveBlur: return CGFloat(max(settings.progressiveFrom, settings.progressiveTo) * 3 + 2)
        case .bloomGlow: return CGFloat(settings.bloomRadius * 3 + 2)
        default: return 0
        }
    }

    /// Pads the layer out so the blur has somewhere to spread; only ever grows, so easing the amount back off
    /// doesn't rebuild anything.
    func growForBlur() throws {
        let margin = Self.blurMargin(kind, settings)
        guard margin > grownMargin else { return }
        let bounds = CGRect(x: 0, y: 0, width: original.image.width, height: original.image.height)
        let room = margin.rounded(.up)
        var target = bounds
        if !canvasSides.contains(.left) { target.origin.x -= room; target.size.width += room }
        if !canvasSides.contains(.right) { target.size.width += room }
        if !canvasSides.contains(.top) { target.origin.y -= room; target.size.height += room }
        if !canvasSides.contains(.bottom) { target.size.height += room }
        try grow(to: target)
        // Measured over the padded sides only, or a side left unpadded would have every change pad it again.
        grownMargin = room
    }

    /// The layer's pixels drawn into a grid covering `extent` (layer pixels), with the transform that places it.
    private func grow(to extent: CGRect) throws {
        let bounds = CGRect(x: 0, y: 0, width: original.image.width, height: original.image.height)
        let target = bounds.union(extent).integral
        guard target != bounds else { return }
        guard target.width <= DocumentLimits.maxSideExtent, target.height <= DocumentLimits.maxSideExtent, target.width * target.height <= DocumentLimits.maxSurfaceExtent else { throw ProjectError.tooLarge }
        let context = try BrushRaster.context(width: Int(target.width), height: Int(target.height), mask: false)
        let inside = bounds.offsetBy(dx: -target.minX, dy: -target.minY)
        if let raster = original.raster { raster.draw(in: inside, context: context) }
        else { BrushRaster.draw(original.image, in: inside, mask: false, context: context) }
        guard let image = context.makeImage() else { throw ExportError.render }
        let toDocument = BrushRaster.pixelToDocument(transform, width: original.image.width, height: original.image.height)
        var expanded = transform
        expanded.size = CGSize(width: target.width * transform.size.width / bounds.width,
                               height: target.height * transform.size.height / bounds.height)
        let middle = CGPoint(x: target.midX, y: target.midY).applying(toDocument)
        expanded.origin = CGPoint(x: middle.x - expanded.size.width / 2, y: middle.y - expanded.size.height / 2)
        grownImage = image
        grownTransform = expanded
        grownInside = inside
        grownMargin = min(bounds.minX - target.minX, bounds.minY - target.minY,
                          target.maxX - bounds.maxX, target.maxY - bounds.maxY)
        try prepare(from: image, placed: expanded)
    }

    /// What the filter and its preview read: the full-size grid, and a copy no larger than `previewLimit` for
    /// everything but the filters that must be made at full size.
    private static func prepared(kind: FilterKind, from source: CGImage, placed: LayerTransform) throws
        -> (mapping: CGAffineTransform, previewSource: CGImage, previewScale: CGFloat, previewMapping: CGAffineTransform) {
        let mapping = BrushRaster.pixelToDocument(placed, width: source.width, height: source.height)
        // Camera Raw keeps native detail throughout slider drags. Noise, grain, dither and scanlines also need
        // full-size pixels: made on a smaller copy they would look coarser once enlarged.
        let factor = [.cameraRaw, .addNoise, .grain, .dither, .scanlines, .contentAwareFill, .removeBackground].contains(kind)
            ? 1 : min(1, previewLimit / CGFloat(max(source.width, source.height)))
        guard factor < 1 else { return (mapping, source, 1, mapping) }
        let w = max(1, Int(CGFloat(source.width) * factor)), h = max(1, Int(CGFloat(source.height) * factor))
        let context = try BrushRaster.context(width: w, height: h, mask: false)
        BrushRaster.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h), mask: false, context: context)
        guard let small = context.makeImage() else { throw ExportError.render }
        return (mapping, small, CGFloat(w) / CGFloat(source.width),
                BrushRaster.pixelToDocument(placed, width: w, height: h))
    }
    private func prepare(from source: CGImage, placed: LayerTransform) throws {
        let ready = try Self.prepared(kind: kind, from: source, placed: placed)
        mapping = ready.mapping
        previewSource = ready.previewSource
        previewScale = ready.previewScale
        previewMapping = ready.previewMapping
        hdrPreviewSource = try Self.hdrPreview(of: original, inside: grownInside,
                                               grid: CGSize(width: source.width, height: source.height), size: ready.previewSource)
        previewSourceVersion &+= 1
    }

    /// An HDR layer's pixels laid out as `size` (the preview's source) is: padded onto `grid` at `inside` when the layer
    /// has grown, then scaled to its size. Nil for any other layer.
    private static func hdrPreview(of asset: ImportedImage, inside: CGRect?, grid: CGSize?, size: CGImage) throws -> CGImage? {
        guard asset.isHDR, let deep = try DeepLayer.flattened(asset) else { return nil }
        guard let grid, let inside else { return try DeepLayer.hdrPreview(of: asset, matching: size) }
        let whole = try DeepLayer.padded(deep, to: grid, inside: inside)
        guard whole.width != size.width || whole.height != size.height else { return whole }
        let context = try DeepLayer.context(width: size.width, height: size.height, hdr: true)
        context.interpolationQuality = .high
        BrushRaster.draw(whole, in: CGRect(x: 0, y: 0, width: size.width, height: size.height), mask: false, context: context)
        return context.makeImage()
    }

    func previewImage(for id: UUID) -> CGImage? { preview && id == layerID ? preparedPreview : nil }
    /// Sliders as they will be rendered: a hidden Camera Raw group contributes nothing.
    func renderSettings() -> FilterSettings {
        var value = settings
        if kind == .cameraRaw {
            value.cameraRaw = value.cameraRaw.applying(showsLight: showsCameraRawLight, showsColor: showsCameraRawColor,
                                                        showsEffects: showsCameraRawEffects, showsCurve: showsCameraRawCurve,
                                                        showsMixer: showsCameraRawMixer, showsGrading: showsCameraRawGrading,
                                                        showsDetail: showsCameraRawDetail, showsOptics: showsCameraRawOptics,
                                                        showsGeometry: showsCameraRawGeometry, showsCalibration: showsCameraRawCalibration)
        }
        return value
    }
    var previewJob: FilterJob {
        var job = FilterJob(kind: kind, image: previewSource, settings: renderSettings(), scale: previewScale, selection: selection,
                            mapping: previewMapping, seed: seed)
        job.canvas = canvas
        job.canvasSides = canvasSides
        job.cameraRawClipping = cameraRawClipping
        job.showsShadowClipping = showsShadowClipping
        job.showsHighlightClipping = showsHighlightClipping
        job.visualizesPointColor = pointColorVisualizeIndex
        job.showsSharpenMask = cameraRawSharpenMask
        if kind == .cameraRaw {
            job.cameraRawBrightness = previewBrightness
            job.cameraRawUsesGPU = previewSource.width * previewSource.height >= MetalCameraRawLookup.minimumPixels
        }
        return job
    }
}

extension EditorSession {
    var canContentAwareFill: Bool {
        canAdjustColors && !isMaskSelected && selection?.isEmpty == false && filterEdit == nil && hueSaturation == nil
    }
    /// `repeating` is Last Filter: the settings go on as they are, without a preview or the panel.
    func beginFilter(_ kind: FilterKind, repeating: Bool = false) {
        if kind == .contentAwareFill && !canContentAwareFill { return }
        guard filterEdit == nil, hueSaturation == nil, kind == .vignette ? canVignette : canAdjustColors else { Platform.beep(); return }
        if gradientEdit != nil {
            Task { await commitGradient(); beginFilter(kind) }
            return
        }
        commitTransform(); cancelCrop(); cancelLasso()
        guard var layer = activeLayer, let document else { return }
        pauseGIFForEditing(for: layer.id)
        layer = pixelEditingLayer(for: layer)
        do {
            // An empty layer has no pixels until something is put on it; Vignette starts it with clear ones.
            let startedEmpty = layer.asset == nil
            if startedEmpty {
                let width = max(1, Int(layer.transform.size.width.rounded())), height = max(1, Int(layer.transform.size.height.rounded()))
                guard let clear = try BrushRaster.context(width: width, height: height, mask: false).makeImage() else { throw ExportError.render }
                layer.asset = ImportedImage(image: clear, thumbnail: try PixelAdjust.thumbnail(of: clear), name: layer.name)
            }
            var settings = filterSettings
            // Progressive Blur starts sharp at the top of the layer's visible part, blurring to its foot; Last Filter
            // keeps the line it had.
            if kind == .progressiveBlur, !repeating {
                let shown = CGRect(origin: layer.transform.origin, size: layer.transform.size)
                    .intersection(CGRect(origin: .zero, size: document.size))
                let area = shown.isNull || shown.isEmpty ? CGRect(origin: .zero, size: document.size) : shown
                settings.progressiveStart = CGPoint(x: area.midX, y: area.minY + area.height * 0.35)
                settings.progressiveEnd = CGPoint(x: area.midX, y: area.maxY)
            }
            // RGB Split's center starts in the middle of the layer's visible part, reaching to its corners.
            if kind == .rgbSplit, !repeating {
                let shown = CGRect(origin: layer.transform.origin, size: layer.transform.size)
                    .intersection(CGRect(origin: .zero, size: document.size))
                let area = shown.isNull || shown.isEmpty ? CGRect(origin: .zero, size: document.size) : shown
                settings.rgbSplitCenter = CGPoint(x: area.midX, y: area.midY)
                settings.rgbSplitReach = max(1, hypot(area.width, area.height) / 2)
            }
            // Volumetric Light starts on the layer's brightest spot: a window, the sky, a lamp.
            if kind == .volumetricLight, !repeating, let image = layer.asset?.image {
                settings.volumetric.center = VolumetricLighting.brightestPoint(in: image)
                    .applying(BrushRaster.pixelToDocument(layer.transform, width: image.width, height: image.height))
            }
            // Gradient Map starts from the foreground and background colors, as in Photoshop.
            if kind == .gradientMap {
                settings.gradientMap = GradientMapSettings(shadows: AdjustmentColor(foregroundColor), highlights: AdjustmentColor(backgroundColor))
            }
            // Content-Aware Fill extends the layer over any of the selection on the canvas past its edge; Vignette on
            // an empty layer covers the whole canvas, which it frames and fills.
            let canvas = CGRect(origin: .zero, size: document.size)
            let fillsCanvas = kind == .vignette && startedEmpty
            let area = kind == .contentAwareFill
                ? selection.map { $0.path.boundingBoxOfPath.intersection(canvas) }.flatMap { $0.isNull || $0.isEmpty ? nil : $0 }
                : fillsCanvas ? canvas : nil
            let edit = try FilterEdit(kind: kind, layer: layer, selection: selection?.clip(canvas: document.size), settings: settings,
                                      growingTo: area, canvas: document.size)
            if fillsCanvas { edit.canvas = canvas }
            edit.startedEmpty = startedEmpty
            edit.repeating = repeating
            filterEdit = edit
            // Volumetric Light's depth model, downloaded the first time: the first preview waits for it, so the fog
            // doesn't draw from its own guess and then jump to the depth. Fetching and compiling it takes about 3 seconds;
            // a slow connection holds it only 5: then the fog guesses until the model is here, and redraws.
            // Without a connection it fails at once, and the fog guesses straight away.
            let waitsForDepth = kind == .volumetricLight && !repeating && !DepthModel.isReady
            if waitsForDepth {
                preparingDepth = true
                edit.waitsForDepth = true
                let guess = Task<Bool, Never> { [weak self, weak edit] in
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, let self, let edit, self.filterEdit === edit, !edit.committing else { return false }
                    edit.waitsForDepth = false
                    self.updateFilter(edit.settings, preview: edit.preview)
                    return true
                }
                Task { [weak self, weak edit] in
                    let ready = await DepthModel.prepare()
                    guess.cancel()
                    let guessed = await guess.value
                    guard let self else { return }
                    self.preparingDepth = false
                    edit?.waitsForDepth = false
                    if ready || !guessed, let edit, self.filterEdit === edit, !edit.committing {
                        self.updateFilter(edit.settings, preview: edit.preview)
                    }
                }
            }
            if kind == .cameraRaw, edit.previewSource.width * edit.previewSource.height >= MetalCameraRawLookup.minimumPixels {
                Task.detached(priority: .utility) { _ = MetalCameraRawLookup.shared }
            }
            // An automatic filter commits what its preview made, so it still needs one.
            if !waitsForDepth { updateFilter(edit.settings, preview: !repeating || kind.isAutomatic) }
        } catch { brushError = error.localizedDescription }
    }

    /// Filter › Last Filter (⌘F): the last filter applied, again, with the same settings and no panel, as in Photoshop.
    var canRepeatLastFilter: Bool {
        guard let lastFilter, filterEdit == nil, hueSaturation == nil else { return false }
        return lastFilter == .vignette ? canVignette : canAdjustColors
    }
    func repeatLastFilter() async {
        guard let kind = lastFilter, canRepeatLastFilter else { Platform.beep(); return }
        if gradientEdit != nil { await commitGradient() }
        beginFilter(kind, repeating: true)
        guard let edit = filterEdit, edit.repeating else { return }
        await commitFilter()
        // Nothing to apply (a zero amount), or it couldn't be: don't leave it open with no panel to close it.
        if filterEdit === edit { cancelFilter() }
    }

    /// Image › Adjustments' one-click commands (Desaturate, Auto Tone, Auto Contrast, Auto Color, Equalize):
    /// apply with the defaults and no panel, as one undo step.
    func applyFilterNow(_ kind: FilterKind) async {
        guard canAdjustColors, filterEdit == nil, hueSaturation == nil else { Platform.beep(); return }
        if gradientEdit != nil { await commitGradient() }
        beginFilter(kind, repeating: true)
        guard let edit = filterEdit, edit.repeating else { return }
        await commitFilter()
        // Nothing to apply, or it couldn't be: don't leave the edit open with no panel to close it.
        if filterEdit === edit { cancelFilter() }
    }

    /// RGB Split's Radial center, clicked or dragged on the canvas (document coordinates).
    func moveRGBSplitCenter(to point: CGPoint) {
        guard let edit = filterEdit, edit.kind == .rgbSplit, edit.settings.rgbSplitRadial, !edit.committing else { return }
        var settings = edit.settings
        settings.rgbSplitCenter = point
        updateFilter(settings, preview: edit.preview)
    }

    /// Volumetric Light's light, clicked or dragged on the canvas (document coordinates).
    func moveVolumetricLight(to point: CGPoint) {
        guard let edit = filterEdit, edit.kind == .volumetricLight, !edit.committing else { return }
        var settings = edit.settings
        settings.volumetric.center = point
        updateFilter(settings, preview: edit.preview)
    }

    /// Progressive Blur's line, dragged on the canvas: either end moved (document coordinates).
    func moveProgressiveBlur(start: CGPoint? = nil, end: CGPoint? = nil) {
        guard let edit = filterEdit, edit.kind == .progressiveBlur, !edit.committing else { return }
        var settings = edit.settings
        if let start { settings.progressiveStart = start }
        if let end { settings.progressiveEnd = end }
        updateFilter(settings, preview: edit.preview)
    }

    func updateFilter(_ settings: FilterSettings, preview: Bool) {
        guard let edit = filterEdit, !edit.committing else { return }
        // The panel's sliders write their values back as it opens; while the first preview waits for the depth model,
        // that isn't a change to draw (only one that changes something is).
        if edit.waitsForDepth, settings.normalized == edit.settings, preview == edit.preview { return }
        edit.settings = settings.normalized
        edit.preview = preview
        // A bigger blur needs more room around the layer than it was given.
        if FilterEdit.blurMargin(edit.kind, edit.settings) > edit.grownMargin {
            do { try edit.growForBlur() }
            catch { brushError = error.localizedDescription }
        }
        if previewAdjustmentEditing(preview: preview) { return }
        if edit.kind.isAutomatic, edit.preparedPreview != nil, edit.preparedSettings == edit.settings { brushRevision += 1; return }
        // An automatic filter still works out its mask with Preview off, so OK has something to apply.
        guard preview || edit.kind.isAutomatic else {
            edit.pending = nil; edit.preparedPreview = nil; brushRevision += 1
            return
        }
        edit.pending = edit.previewJob
        edit.pendingTransform = edit.grownTransform
        renderFilterPreview(edit)
    }

    /// Renders the newest settings; changes that arrive mid-render wait for it rather than
    /// cancelling it, so dragging a slider keeps the canvas updating.
    private func renderFilterPreview(_ edit: FilterEdit) {
        guard filterEdit === edit, edit.previewTask == nil, var job = edit.pending else { return }
        if job.kind == .cameraRaw { job.cameraRawBrightness = edit.previewBrightness }
        edit.pending = nil
        let placement = edit.pendingTransform
        let sourceVersion = edit.previewSourceVersion
        let hdrSource = edit.kind.isAutomatic ? nil : edit.hdrPreviewSource
        edit.preparing = true
        edit.previewError = nil
        edit.previewTask = Task { @MainActor [weak self, weak edit] in
            let result = await Self.previewWork(job, hdrSource: hdrSource)
            guard let self, let edit, self.filterEdit === edit, !Task.isCancelled else {
                if job.cameraRawUsesGPU { Task.detached(priority: .utility) { MetalCameraRawLookup.shared?.discardBuffers() } }
                return
            }
            edit.previewTask = nil
            edit.preparing = false
            // Made before the layer grew for a bigger blur: it still shows, in the place it was made for, until the
            // render from the grown layer replaces it.
            let current = sourceVersion == edit.previewSourceVersion
            if current, let brightness = result.3 { edit.cachePreviewBrightness(brightness) }
            edit.previewError = result.2
            if let scope = result.1 { edit.cameraRawScope = scope }
            if (edit.preview || edit.kind.isAutomatic), current || !edit.kind.isAutomatic {
                edit.preparedPreview = result.0
                edit.preparedTransform = placement
                edit.preparedSettings = current ? job.settings : nil
                self.brushRevision += 1
            }
            self.renderFilterPreview(edit)
        }
    }
    /// What a preview shows, made off the main actor: the image, Camera Raw's scope, or why there is none, and what
    /// Camera Raw's adaptive sliders read from the picture, measured here when the job doesn't carry it yet. Cancelling
    /// the task that waits for it cancels the work, so a long fill that checks for cancellation stops rather than
    /// running on unseen.
    nonisolated static func previewWork(_ job: FilterJob, hdrSource: CGImage? = nil) async
        -> (CGImage?, CameraRawScope?, String?, CameraRawTables.Brightness?) {
        let work = Task.detached(priority: .userInitiated) { () -> (CGImage?, CameraRawScope?, String?, CameraRawTables.Brightness?) in
            var run = job
            // Measure once on the worker, then reuse it for every slider update in this session.
            if run.kind == .cameraRaw, run.cameraRawBrightness == nil {
                run.cameraRawBrightness = CameraRawTables.brightness(of: run.image)
            }
            do {
                // An HDR layer previews from its HDR pixels, as OK makes it, shown clipped to white.
                if let hdrSource {
                    let made = try PixelFilter.previewHDR(run, from: hdrSource)
                    let scope = run.kind == .cameraRaw ? try CameraRawScope.preview(run).scope : nil
                    return (try DeepLayer.dithered(made), scope, nil, run.cameraRawBrightness)
                }
                if run.kind == .cameraRaw {
                    let made = try CameraRawScope.preview(run)
                    return (made.image, made.scope, nil, run.cameraRawBrightness)
                }
                return (try PixelFilter.run(run), nil, nil, run.cameraRawBrightness)
            } catch {
                return (nil, nil, error.localizedDescription, run.cameraRawBrightness)
            }
        }
        return await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
    }

    func cancelFilter() {
        // A filter color still being picked goes with the panel.
        if case .gradientMap = colorPicker?.target { closeColorPicker(commit: false) }
        if case .vignette = colorPicker?.target { closeColorPicker(commit: false) }
        if case .rimLight = colorPicker?.target { closeColorPicker(commit: false) }
        if case .volumetricLight = colorPicker?.target { closeColorPicker(commit: false) }
        if case .dither = colorPicker?.target { closeColorPicker(commit: false) }
        if finishAdjustmentEditing(commit: false) { return }
        guard let edit = filterEdit, !edit.committing else { return }
        edit.previewTask?.cancel()
        if edit.kind == .cameraRaw, edit.previewJob.cameraRawUsesGPU {
            Task.detached(priority: .utility) { MetalCameraRawLookup.shared?.discardBuffers() }
        }
        filterEdit = nil
        brushRevision += 1
    }

    func commitFilter() async {
        if case .gradientMap = colorPicker?.target { closeColorPicker(commit: true) }
        if case .vignette = colorPicker?.target { closeColorPicker(commit: true) }
        if case .rimLight = colorPicker?.target { closeColorPicker(commit: true) }
        if case .dither = colorPicker?.target { closeColorPicker(commit: true) }
        if finishAdjustmentEditing(commit: true) { return }
        guard let edit = filterEdit, !edit.committing else { return }
        if edit.kind.isAutomatic {
            await edit.previewTask?.value
            guard filterEdit === edit, !edit.committing, edit.preparedPreview != nil, edit.previewError == nil else { return }
            // Remove Background masks from the full-size image, so a preview made at preview size is fine to discard.
        }
        // A hidden Camera Raw group is absent from the layer. Remember that rendered grade, including
        // when every remaining amount is zero, so the next open does not put the hidden sliders back.
        let rendered = edit.renderSettings()
        if edit.kind == .cameraRaw { filterSettings = rendered }
        // No distortion to remove: close as Cancel does, without an undo step.
        if (edit.kind == .lensCorrection && edit.settings.distortion == 0)
            || (edit.kind == .vignette && edit.settings.vignetteAmount == 0)
            || (edit.kind == .bloomGlow && edit.settings.bloomAmount == 0)
            || (edit.kind == .sharpen && edit.settings.sharpenAmount == 0)
            || (edit.kind == .reduceNoise && edit.settings.reduceNoiseLuminance == 0 && edit.settings.reduceNoiseColor == 0)
            || (edit.kind == .lensEffects && edit.settings.lens.isIdentity)
            || (edit.kind == .rimLight && edit.settings.rimLight.isIdentity)
            || (edit.kind == .volumetricLight && edit.settings.volumetric.isIdentity)
            || (edit.kind == .tonalContrast && (edit.settings.tonalAmount == 0 ||
                (edit.settings.tonalShadows == 0 && edit.settings.tonalMidtones == 0 && edit.settings.tonalHighlights == 0)))
            || (edit.kind == .exposure && edit.settings.exposure == ExposureSettings())
            || (edit.kind == .grain && edit.settings.grain.amount == 0)
            || (edit.kind == .cameraRaw && rendered.cameraRaw.isIdentity) { cancelFilter(); return }
        edit.committing = true
        edit.previewTask?.cancel()
        if edit.kind != .cameraRaw { filterSettings = edit.settings }
        if edit.kind.repeatsAsLastFilter { lastFilter = edit.kind }
        isProjectBusy = true
        // The preview stays up until the result is on the layer, so the canvas never flashes the original.
        defer {
            filterEdit = nil; isProjectBusy = false; brushRevision += 1
            if edit.kind == .cameraRaw, edit.previewJob.cameraRawUsesGPU {
                Task.detached(priority: .utility) { MetalCameraRawLookup.shared?.discardBuffers() }
            }
        }
        // Remove Background masks the background out rather than erasing it, so it can be brought back at any time
        // by painting the mask, disabling it, or deleting it.
        if edit.kind == .removeBackground { await commitBackgroundMask(edit); return }
        // A blur that keeps the layer's transparency has no use for room around it (opening the panel may have made
        // some for the blur it started with): it's applied to the layer as it was, which leaves its size alone.
        let keepsOutline = edit.kind == .gaussianBlur && edit.settings.preserveTransparency
        let mapping = keepsOutline
            ? BrushRaster.pixelToDocument(edit.transform, width: edit.original.image.width, height: edit.original.image.height)
            : edit.mapping
        var job = FilterJob(kind: edit.kind, image: keepsOutline ? edit.original.image : edit.grownImage ?? edit.original.image,
                            settings: edit.renderSettings(), scale: 1, selection: edit.selection, mapping: mapping, seed: edit.seed)
        job.canvas = edit.canvas
        job.canvasSides = edit.canvasSides
        let cached = edit.kind.isAutomatic && edit.preparedSettings == edit.settings ? edit.preparedPreview : nil
        do {
            let grown = keepsOutline ? nil : edit.grownTransform
            let spreads = edit.kind == .gaussianBlur || edit.kind == .motionBlur || edit.kind == .progressiveBlur || edit.kind == .bloomGlow
            // A 16-bit layer runs the filter on its 16-bit pixels, padded as the 8-bit ones were (`DeepLayer.run`).
            // These work on the 8-bit pixels instead, and the layer is made 16-bit again after (`keepLayerDepths`):
            // Content-Aware Fill makes new pixels from scratch; Dither's result is a few levels by design (three runs read
            // between would mix its patterns into colors); Remove Background would find the subject three times over.
            let rasterizes = edit.kind == .contentAwareFill || edit.kind == .dither || edit.kind == .removeBackground
            let deep = rasterizes ? nil : try DeepLayer.flattened(edit.original)
            let deepGrid = keepsOutline ? nil : edit.grownImage.flatMap { grownImage in
                edit.grownInside.map { (size: CGSize(width: grownImage.width, height: grownImage.height), inside: $0) }
            }
            let made = try await Task.detached(priority: .userInitiated) { () -> (asset: ImportedImage, transform: LayerTransform?) in
                // Exposure on an HDR layer, exactly: turned down, it brings highlights into view.
                if let deep, DeepLayer.isHDR(deep), job.kind == .exposure {
                    var result = try DeepLayer.exposure(deep, job.settings.exposure)
                    if let selection = job.selection {
                        result = try PixelAdjust.blend(result, over: deep, through: selection, pixelToDocument: job.mapping,
                                                       isMask: false, sixteenBit: true)
                    }
                    return (try DeepLayer.asset(result, name: job.kind.rawValue), grown)
                }
                if let deep, let lookup = job.kind.sixteenBitLookup(job.settings) {
                    // Channels that mix go through the adjustment's color lookup at 16 bits.
                    var result = try DeepLayer.lookup(deep, cube: lookup.cube, dimension: lookup.dimension)
                    if let selection = job.selection {
                        result = try PixelAdjust.blend(result, over: deep, through: selection, pixelToDocument: job.mapping,
                                                       isMask: false, sixteenBit: true)
                    }
                    return (try DeepLayer.asset(result, name: job.kind.rawValue), grown)
                }
                if let deep {
                    let input = try deepGrid.map { try DeepLayer.padded(deep, to: $0.size, inside: $0.inside) } ?? deep
                    var result: CGImage
                    if job.kind.runsAtSixteenBits {
                        var run = job
                        run.image = input
                        run.sixteenBit = true
                        result = try PixelFilter.run(run)
                    } else {
                        result = try DeepLayer.run(input, mixesChannels: job.kind.mixesChannels) { half in
                            var run = job
                            run.image = half
                            return try PixelFilter.run(run)
                        }
                    }
                    var placed = grown
                    if spreads, let grown, let crop = try PixelFilter.trimCrop(try DeepLayer.dithered(result)),
                       let cropped = result.cropping(to: crop) {
                        placed = PixelFilter.trimmedTransform(grown, crop: crop, width: result.width, height: result.height)
                        result = cropped
                    }
                    return (try DeepLayer.asset(result, name: job.kind.rawValue), placed)
                }
                var image = try cached ?? PixelFilter.run(job)
                var placed = grown
                if spreads, let grown {
                    let trimmed = try PixelFilter.trimmed(image, placed: grown)
                    image = trimmed.image
                    placed = trimmed.transform
                }
                return (ImportedImage(image: image, thumbnail: try PixelAdjust.thumbnail(of: image), name: job.kind.rawValue), placed)
            }.value
            let asset = made.asset
            guard let index = document?.layers.firstIndex(where: { $0.id == edit.layerID }),
                  let current = document?.layers[index],
                  displayedAsset(for: current)?.image === edit.original.image || (edit.startedEmpty && current.asset == nil),
                  pixelEditTransformMatches(current, transform: edit.transform) else { return }
            // A grown layer's mask (covering the old grid) is carried onto the new one, its edge tone past the old edge.
            var mask = current.mask
            if current.gifAnimation == nil, let grown, let owned = current.mask, owned.placement == nil,
               owned.asset.image.width > 1 || owned.asset.image.height > 1 {
                var enabled = owned
                enabled.isEnabled = true
                guard let carried = enabled.clipImage(placement: current.transform, over: grown,
                                                      width: asset.image.width, height: asset.image.height) else { throw ExportError.render }
                mask = owned.replacing(try LayerMask.asset(from: carried))
            }
            let edited = try layerByEditingPixels(current, asset: asset, transform: made.transform ?? current.transform, mask: mask)
            beginEdit(edit.kind.rawValue)
            document?.layers[index] = edited
            endEdit()
        } catch { brushError = error.localizedDescription }
    }

    /// Remove Background as a layer mask: the subject stays white, the background black. A mask already on the layer
    /// (in the layer's own grid) is kept, hiding whatever either one hides; with a selection, only the selected part
    /// of the mask changes.
    private func commitBackgroundMask(_ edit: FilterEdit) async {
        let source = edit.original.image
        let current = document?.layers.first(where: { $0.id == edit.layerID })
        let existing = current?.mask.flatMap { owned in
            owned.placement == nil && owned.asset.image.width == source.width && owned.asset.image.height == source.height
                ? owned.asset.image : nil
        }
        let selection = edit.selection, mapping = edit.mapping, settings = edit.settings.normalized
        do {
            let made = try await Task.detached(priority: .userInitiated) { () -> CGImage in
                var mask = try SubjectRemoval.subjectMask(source, under: existing, settings: settings)
                if let selection, let base = existing {
                    mask = try PixelAdjust.blend(mask, over: base, through: selection, pixelToDocument: mapping, isMask: true)
                } else if let selection {
                    let white = try BrushRaster.context(width: source.width, height: source.height, mask: true)
                    white.setFillColor(gray: 1, alpha: 1)
                    white.fill(CGRect(x: 0, y: 0, width: source.width, height: source.height))
                    guard let opaque = white.makeImage() else { throw ExportError.render }
                    mask = try PixelAdjust.blend(mask, over: opaque, through: selection, pixelToDocument: mapping, isMask: true)
                }
                return mask
            }.value
            guard let index = document?.layers.firstIndex(where: { $0.id == edit.layerID }),
                  let layer = document?.layers[index], displayedAsset(for: layer)?.image === edit.original.image,
                  pixelEditTransformMatches(layer, transform: edit.transform) else { return }
            let asset = try LayerMask.asset(from: made)
            beginEdit(edit.kind.rawValue)
            document?.layers[index].mask = layer.mask.map { $0.replacing(asset) } ?? LayerMask(asset: asset)
            document?.layers[index].mask?.isEnabled = true
            isMaskSelected = true
            endEdit()
        } catch { brushError = error.localizedDescription }
    }
}

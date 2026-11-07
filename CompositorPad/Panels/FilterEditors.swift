import UIKit

/// The editor for a filter, or an adjustment layer of the same kind, as the Mac's filter panel: a row for each of the
/// filter's settings, then Preview, and Cancel and OK. Like the Mac's, it has no Reset.
final class FilterEditorController: AdjustmentEditorController {
    /// A row of the Mac's filter panel: a slider and an exact field for one setting.
    struct Row {
        let caption: String
        let key: WritableKeyPath<FilterSettings, Double>
        let range: ClosedRange<Double>
        let unit: String?
        /// How many decimals the row sets and shows.
        let decimals: Int
        /// Whether the slider gives the small values most of its travel.
        let logarithmic: Bool
        /// What the row does, as the Mac's help says it.
        var help: String? = nil
        /// What the row does, as VoiceOver's hint says it (`setHelp`); none where the caption says it.
        var hint: String? = nil
        /// When the row shows, as Remove Background's Advanced rows; always if nil.
        var shown: ((FilterSettings) -> Bool)? = nil
        /// The row's colored track, as the Mac's Camera Raw sliders: a double tap on its caption or thumb then puts the
        /// value back, a plain track's too. Nil for the system's slider, which doesn't reset.
        var track: ((FilterSettings) -> CameraRawSliderTrack)? = nil
    }

    /// A color, as a swatch that opens the color picker on it, titled.
    struct Swatch {
        let title: String
        let value: (FilterSettings) -> AdjustmentColor
        let open: (EditorSession) -> Void
    }

    /// What the Mac's filter panel puts in a filter's editor, in order. A control with `shown` shows only when it says
    /// so, as Dither's rows for its style. A control's `help` is the Mac's, and its `hint` VoiceOver's (`setHelp`).
    enum Control {
        case slider(Row)
        /// A choice among `titles`, as segments, captioned or not; `chosen` reads which, and `choose` sets it. `hints` has
        /// each segment's, which VoiceOver reads on its own.
        case choice(caption: String?, titles: [String], help: String?, hints: [String]?, chosen: (FilterSettings) -> Int,
                    choose: (inout FilterSettings, Int) -> Void, shown: ((FilterSettings) -> Bool)? = nil)
        /// A choice among `groups` of names, as a pop-up, captioned.
        case popUp(caption: String, groups: [[String]], help: String? = nil, hint: String? = nil, chosen: (FilterSettings) -> String,
                   choose: (inout FilterSettings, String) -> Void, shown: ((FilterSettings) -> Bool)? = nil)
        case checkbox(String, WritableKeyPath<FilterSettings, Bool>, help: String? = nil, hint: String? = nil,
                      shown: ((FilterSettings) -> Bool)? = nil)
        /// Text typed into a field, captioned, as Dither's Characters.
        case field(caption: String, key: WritableKeyPath<FilterSettings, String>, help: String?, hint: String?,
                   shown: ((FilterSettings) -> Bool)? = nil)
        /// A section's title, as Color Balance's Shadows, Midtones and Highlights.
        case heading(String)
        /// The gradient the settings make, left to right, as Gradient Map's bar.
        case gradient((FilterSettings) -> [AdjustmentColor])
        /// Swatches side by side, each with its title after it, as Gradient Map's ends, or before it, as Dither's Dark
        /// and Light; a tap opens the color picker on one.
        case swatches([Swatch], titlesFirst: Bool = false, shown: ((FilterSettings) -> Bool)? = nil)
        /// A color, as a swatch that opens the color picker on it.
        case color(caption: String, help: String?, hint: String?, value: (FilterSettings) -> AdjustmentColor, open: (EditorSession) -> Void)
        /// What the filter does, in the panel's words.
        case text(String)
        /// A button that does something to the edit, as Camera Raw's Auto White Balance.
        case action(String, help: String? = nil, hint: String? = nil, run: (EditorSession) -> Void)
        /// A note on a setting, quieter.
        case note(String, shown: ((FilterSettings) -> Bool)? = nil)
    }

    /// Each kind's controls, as the Mac's filter panel (FilterSheet) lays them out, with its ranges, units and decimals.
    static let controls: [FilterKind: [Control]] = [
        .gaussianBlur: [
            .slider(Row(caption: "Radius", key: \.radius, range: 0.1...250, unit: "px", decimals: 1, logarithmic: true)),
            .checkbox("Preserve Transparency", \.preserveTransparency,
                      help: "Blur only the colors, keeping the layer's outline and transparency as they are",
                      hint: "Blurs only the colors, keeping the layer's outline and its transparency."),
        ],
        .progressiveBlur: [
            .note("Click and drag two points on canvas"),
            .choice(caption: "Shape", titles: ["Linear", "Radial"],
                    help: "Linear blurs along the line; Radial keeps the start sharp and blurs outwards",
                    hints: ["Blurs along the line.", "Keeps the start sharp and blurs outwards."],
                    chosen: { $0.progressiveRadial ? 1 : 0 }, choose: { $0.progressiveRadial = $1 == 1 }),
            .slider(Row(caption: "From", key: \.progressiveFrom, range: 0...250, unit: "px", decimals: 1, logarithmic: false,
                        help: "The blur where the line starts")),
            .slider(Row(caption: "To", key: \.progressiveTo, range: 0...250, unit: "px", decimals: 1, logarithmic: false,
                        help: "The blur where the line ends, and past it")),
            .checkbox("Invert", \.progressiveInverted, help: "Swap From and To: blur the start and sharpen toward the end",
                      hint: "Blurs the start and sharpens toward the end."),
        ],
        .sharpen: [
            .slider(Row(caption: "Amount", key: \.sharpenAmount, range: 0...300, unit: "%", decimals: 0, logarithmic: false,
                        help: "How strongly edges and fine detail are brought out",
                        hint: "Brings out edges and fine detail.")),
            .slider(Row(caption: "Radius", key: \.sharpenRadius, range: 0.1...20, unit: "px", decimals: 1, logarithmic: true,
                        help: "How fine the detail it sharpens: small for crisp texture, larger for a punchier look",
                        hint: "How fine the sharpened detail is; small for crisp texture, larger for a punchier look.")),
        ],
        .reduceNoise: [
            .slider(Row(caption: "Strength", key: \.reduceNoiseLuminance, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much grain is smoothed from the picture's brightness",
                        hint: "Smooths grain from the picture's brightness.")),
            .slider(Row(caption: "Preserve Details", key: \.reduceNoiseDetail, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much fine texture and edges are kept while the grain is smoothed",
                        hint: "Keeps fine texture and edges while smoothing grain.")),
            .slider(Row(caption: "Color Noise", key: \.reduceNoiseColor, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much colored speckle is smoothed into the colors around it",
                        hint: "Smooths colored speckle into the colors around it.")),
        ],
        .rgbSplit: [
            .choice(caption: "Shape", titles: ["Linear", "Radial"],
                    help: "Linear splits along one direction; Radial splits outwards from a center, sharp there",
                    hints: ["Splits along one direction.", "Splits outwards from a center, sharp there."],
                    chosen: { $0.rgbSplitRadial ? 1 : 0 }, choose: { $0.rgbSplitRadial = $1 == 1 }),
            .note("Click or drag on the canvas to move the center", shown: { $0.rgbSplitRadial }),
            .slider(Row(caption: "Distance", key: \.rgbSplitDistance, range: 0...200, unit: "px", decimals: 0, logarithmic: false,
                        help: "How far the colors spread apart, red one way and blue the other",
                        hint: "How far the colors spread apart, red one way and blue the other.")),
            .slider(Row(caption: "Blur", key: \.rgbSplitBlur, range: 0...400, unit: "px", decimals: 0, logarithmic: false,
                        help: "Smear the split into streaks along its direction",
                        hint: "Smears the split into streaks along its direction.")),
            .slider(Row(caption: "Angle", key: \.rgbSplitAngle, range: -180...180, unit: "°", decimals: 0, logarithmic: false,
                        help: "Which way the colors spread", hint: "Which way the colors spread.",
                        shown: { !$0.rgbSplitRadial })),
        ],
        .lensEffects: [
            .popUp(caption: "Effect", groups: [LensEffect.allCases.map(\.rawValue)], chosen: { $0.lens.effect.rawValue },
                   choose: { settings, name in if let effect = LensEffect(rawValue: name) { settings.lens.effect = effect } }),
            .slider(Row(caption: "Amount", key: \.lens.flareAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        shown: { $0.lens.effect == .anamorphicFlare })),
            .slider(Row(caption: "Length", key: \.lens.flareLength, range: 1...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far the streaks reach across the picture",
                        hint: "How far the streaks reach across the picture.",
                        shown: { $0.lens.effect == .anamorphicFlare })),
            .slider(Row(caption: "Threshold", key: \.lens.threshold, range: 50...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How bright a light has to be to flare; near 100, only the biggest, brightest spots",
                        hint: "How bright a light has to be to flare; near 100, only the biggest, brightest spots.",
                        shown: { $0.lens.effect == .anamorphicFlare || $0.lens.effect == .starburst })),
            .slider(Row(caption: "Blue", key: \.lens.flareBlue, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far the lens's coatings turn each streak blue along its length; none keeps the light's own color",
                        hint: "Turns each streak blue along its length; none keeps the light's own color.",
                        shown: { $0.lens.effect == .anamorphicFlare })),
            .slider(Row(caption: "Amount", key: \.lens.starAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        shown: { $0.lens.effect == .starburst })),
            .slider(Row(caption: "Length", key: \.lens.starLength, range: 2...40, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far the spikes reach", hint: "How far the spikes reach.",
                        shown: { $0.lens.effect == .starburst })),
            .slider(Row(caption: "Angle", key: \.lens.starAngle, range: -180...180, unit: "°", decimals: 0, logarithmic: false,
                        shown: { $0.lens.effect == .starburst })),
            .choice(caption: "Points", titles: LensEffectSettings.starPointChoices.map(String.init), help: nil, hints: nil,
                    chosen: { LensEffectSettings.starPointChoices.firstIndex(of: $0.lens.starPoints) ?? 0 },
                    choose: { settings, index in
                        guard LensEffectSettings.starPointChoices.indices.contains(index) else { return }
                        settings.lens.starPoints = LensEffectSettings.starPointChoices[index]
                    }, shown: { $0.lens.effect == .starburst }),
            .slider(Row(caption: "Strength", key: \.lens.mistStrength, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much light scatters: a soft halo around bright areas, and gently lifted shadows",
                        hint: "How much light scatters: a soft halo around bright areas, and gently lifted shadows.",
                        shown: { $0.lens.effect == .mist })),
            .slider(Row(caption: "Size", key: \.lens.mistSize, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far the light spreads", hint: "How far the light spreads.",
                        shown: { $0.lens.effect == .mist })),
            .slider(Row(caption: "Amount", key: \.lens.prismAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        shown: { $0.lens.effect == .prism })),
            .slider(Row(caption: "Copies", key: \.lens.prismCopies, range: 1...8, unit: nil, decimals: 0, logarithmic: false,
                        help: "How many times the picture echoes, each fainter",
                        hint: "How many times the picture echoes, each fainter.",
                        shown: { $0.lens.effect == .prism })),
            .slider(Row(caption: "Offset", key: \.lens.prismOffset, range: 0...50, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far apart the copies are", hint: "How far apart the copies are.",
                        shown: { $0.lens.effect == .prism })),
            .slider(Row(caption: "Angle", key: \.lens.prismAngle, range: -180...180, unit: "°", decimals: 0, logarithmic: false,
                        help: "Which way the copies step", hint: "Which way the copies step.",
                        shown: { $0.lens.effect == .prism })),
            .slider(Row(caption: "Blur", key: \.lens.prismBlur, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Soften the copies, more the farther they're pushed",
                        hint: "Softens the copies, more the farther they're pushed.",
                        shown: { $0.lens.effect == .prism })),
            .slider(Row(caption: "Fringe", key: \.lens.prismFringe, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Split each copy's red and blue apart, as glass does; 0 keeps the copies crisp",
                        hint: "Splits each copy's red and blue apart, as glass does.",
                        shown: { $0.lens.effect == .prism })),
            .choice(caption: "Direction", titles: ["One Way", "Both Ways"],
                    help: "Copies to one side of the picture, or out to both", hints: nil,
                    chosen: { $0.lens.prismBothWays ? 1 : 0 }, choose: { $0.lens.prismBothWays = $1 == 1 },
                    shown: { $0.lens.effect == .prism }),
            .slider(Row(caption: "Size", key: \.lens.bokehRadius, range: LensEffectSettings.bokehSizes, unit: "%", decimals: 1, logarithmic: false,
                        help: "How far out of focus: the size of each disc",
                        hint: "How far out of focus: the size of each disc.",
                        shown: { $0.lens.effect == .bokeh })),
            .slider(Row(caption: "Brightness", key: \.lens.bokehBrightness, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How brightly lights open into discs", hint: "How brightly lights open into discs.",
                        shown: { $0.lens.effect == .bokeh })),
            .slider(Row(caption: "Ring", key: \.lens.bokehRing, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Light gathered at each disc's rim, as some lenses draw it",
                        hint: "Light gathered at each disc's rim, as some lenses draw it.",
                        shown: { $0.lens.effect == .bokeh })),
            .popUp(caption: "Shape", groups: [BokehShape.allCases.map(\.rawValue)],
                   help: "The aperture's shape: round wide open, a hexagon of blades, an anamorphic oval, or a cat's eye toward the edges",
                   hint: "The aperture's shape.",
                   chosen: { $0.lens.bokehShape.rawValue },
                   choose: { settings, name in if let shape = BokehShape(rawValue: name) { settings.lens.bokehShape = shape } },
                   shown: { $0.lens.effect == .bokeh }),
        ],
        .scanlines: [
            .slider(Row(caption: "Line Spacing", key: \.scanlines.lineSpacing, range: ScanlinesSettings.lineSpacingRange, unit: "px", decimals: 0,
                        logarithmic: false, help: "How far apart the screen's lines are", hint: "How far apart the screen's lines are.")),
            .slider(Row(caption: "Thickness", key: \.scanlines.thickness, range: 5...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much of the gap a bright line fills; dimmer parts draw it thinner",
                        hint: "How much of the gap a bright line fills; dimmer parts draw it thinner.")),
            .slider(Row(caption: "Glow", key: \.scanlines.glow, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Light blooming around the lines, like a CRT's phosphors",
                        hint: "Light blooming around the lines, like a CRT's phosphors.")),
            .slider(Row(caption: "Dots", key: \.scanlines.dots, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Break the lines into beads where the picture is darker than this, blending into solid lines where it's brighter",
                        hint: "Breaks the lines into beads where the picture is darker than this.")),
            .slider(Row(caption: "Displace", key: \.scanlines.displace, range: ScanlinesSettings.displaceRange, unit: "px", decimals: 0,
                        logarithmic: false, help: "Lift the lines where the picture is bright, or lower them when negative, so they swell into its shapes",
                        hint: "Lifts the lines where the picture is bright, so they swell into its shapes.")),
            .slider(Row(caption: "Smoothness", key: \.scanlines.smoothness, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far the brightness is smoothed before it displaces the lines, from sharp ridges to rounded hills",
                        hint: "How far the brightness is smoothed before it displaces the lines.")),
            .slider(Row(caption: "Threshold", key: \.scanlines.threshold, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Draw no line where the picture is darker than this, leaving the screen dark",
                        hint: "Draws no line where the picture is darker than this.")),
            .slider(Row(caption: "Wobble", key: \.scanlines.wobble, range: ScanlinesSettings.wobbleRange, unit: "px", decimals: 0, logarithmic: false,
                        help: "Make the lines waver sideways down the screen, like a CRT losing sync",
                        hint: "Makes the lines waver sideways down the screen.")),
            .slider(Row(caption: "Color Split", key: \.scanlines.split, range: ScanlinesSettings.splitRange, unit: "px", decimals: 0, logarithmic: false,
                        help: "Move the red and blue apart, for colored fringes on the lines",
                        hint: "Moves the red and blue apart, for colored fringes on the lines.")),
            .slider(Row(caption: "Density", key: \.scanlines.density, range: -100...100, unit: nil, decimals: 0, logarithmic: false,
                        help: "Darker or lighter before the lines are drawn", hint: "Darkens or lightens before the lines are drawn.")),
            .slider(Row(caption: "Contrast", key: \.scanlines.contrast, range: -100...100, unit: nil, decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Black Level", key: \.scanlines.blackLevel, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How bright the lines are where the picture is black, so they show even over black",
                        hint: "How bright the lines are where the picture is black.")),
            .popUp(caption: "Colors", groups: [DitherColors.allCases.map(\.rawValue)], chosen: { $0.scanlines.colors.rawValue },
                   choose: { settings, name in if let colors = DitherColors(rawValue: name) { settings.scanlines.colors = colors } }),
            .swatches([Swatch(title: "Dark", value: \.scanlines.dark, open: { $0.openDitherColorPicker(light: false) }),
                       Swatch(title: "Light", value: \.scanlines.light, open: { $0.openDitherColorPicker(light: true) })],
                      titlesFirst: true, shown: { $0.scanlines.colors == .twoColors }),
        ],
        .volumetricLight: [
            .note("Click or drag on the canvas to move the light"),
            .color(caption: "Color", help: "Choose the light's color", hint: "Opens the color picker for the light.",
                   value: \.volumetric.color, open: { $0.openVolumetricLightColorPicker() }),
            .slider(Row(caption: "Haze", key: \.volumetric.haze, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How thick the air is: haze lit by the light, thinner in front of the subject",
                        hint: "How thick the air is: haze lit by the light, thinner in front of the subject.")),
            .slider(Row(caption: "Distance", key: \.volumetric.distance, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far into the scene the haze begins: low reaches up to the camera, high leaves all but the farthest parts clear",
                        hint: "How far into the scene the haze begins.")),
            .slider(Row(caption: "Depth Contrast", key: \.volumetric.depthContrast, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Spread out depths bunched together, such as a distant city, so the haze builds through them in steps; 0 keeps the depth as the model sees it",
                        hint: "Spreads out depths bunched together, so the haze builds through them in steps.")),
            .slider(Row(caption: "Size", key: \.volumetric.size, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How big the light is", hint: "How big the light is.")),
            .slider(Row(caption: "Intensity", key: \.volumetric.intensity, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How bright the beams are", hint: "How bright the beams are.")),
            .slider(Row(caption: "Length", key: \.volumetric.length, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How far from the light the beams reach", hint: "How far from the light the beams reach.")),
            .slider(Row(caption: "Shafts", key: \.volumetric.shafts, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much the beams break up into separate shafts", hint: "How much the beams break up into separate shafts.")),
            .checkbox("Keep Subject Clear", \.volumetric.keepsSubjectClear,
                      help: "Keep the subject clear of the haze; off, it's hazed by its own distance, so a figure far off is misted",
                      hint: "Keeps the subject clear of the haze."),
        ],
        .motionBlur: [
            .slider(Row(caption: "Angle", key: \.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Distance", key: \.distance, range: 1...2000, unit: "px", decimals: 0, logarithmic: true)),
        ],
        .addNoise: [
            .slider(Row(caption: "Amount", key: \.amount, range: 0.1...400, unit: "%", decimals: 1, logarithmic: true)),
            .choice(caption: "Distribution", titles: ["Uniform", "Gaussian"], help: nil, hints: nil, chosen: { $0.gaussian ? 1 : 0 },
                    choose: { $0.gaussian = $1 == 1 }),
            .checkbox("Monochromatic", \.monochromatic),
        ],
        .exposure: [
            .slider(Row(caption: "Exposure", key: \.exposure.exposure, range: ExposureSettings.exposureRange, unit: nil, decimals: 2,
                        logarithmic: false)),
            .slider(Row(caption: "Offset", key: \.exposure.offset, range: ExposureSettings.offsetRange, unit: nil, decimals: 4, logarithmic: false)),
            .slider(Row(caption: "Gamma", key: \.exposure.gamma, range: ExposureSettings.gammaRange, unit: nil, decimals: 2, logarithmic: true)),
        ],
        .grain: [
            .slider(Row(caption: "Amount", key: \.grain.amount, range: GrainSettings.amountRange, unit: nil, decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Size", key: \.grain.size, range: GrainSettings.sizeRange, unit: "px", decimals: 1, logarithmic: true)),
            .slider(Row(caption: "Roughness", key: \.grain.roughness, range: GrainSettings.roughnessRange, unit: nil, decimals: 0,
                        logarithmic: false)),
        ],
        .bloomGlow: [
            .slider(Row(caption: "Amount", key: \.bloomAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Radius", key: \.bloomRadius, range: 1...150, unit: "px", decimals: 0, logarithmic: true)),
        ],
        .tonalContrast: [
            .slider(Row(caption: "Amount", key: \.tonalAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Shadows", key: \.tonalShadows, range: -100...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Midtones", key: \.tonalMidtones, range: -100...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Highlights", key: \.tonalHighlights, range: -100...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Radius", key: \.tonalRadius, range: 1...100, unit: "px", decimals: 0, logarithmic: true)),
        ],
        .contentAwareFill: [.text("Fill the selection using surrounding pixels from this layer.")],
        .removeBackground: [
            .text("Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time."),
            .choice(caption: nil, titles: BackgroundQuality.allCases.map(\.rawValue),
                    help: "Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur",
                    hints: BackgroundQuality.allCases.map(\.hint),
                    chosen: { BackgroundQuality.allCases.firstIndex(of: $0.backgroundQuality) ?? 0 },
                    choose: { $0.backgroundQuality = BackgroundQuality.allCases[$1] }),
            .slider(Row(caption: "Refine", key: \.refineEdges, range: 0...40, unit: "px", decimals: 0, logarithmic: false,
                        help: "Pull the mask onto the image's own edges, which recovers hair and fur",
                        hint: "Pulls the mask onto the image's own edges, recovering hair and fur.", shown: { $0.backgroundQuality == .advanced })),
            .slider(Row(caption: "Contrast", key: \.matteContrast, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Clear the haze that leaves background showing through thin areas",
                        hint: "Clears the haze that leaves background showing through thin areas.", shown: { $0.backgroundQuality == .advanced })),
            .slider(Row(caption: "Shift Edge", key: \.shiftEdge, range: -10...10, unit: "px", decimals: 0, logarithmic: false,
                        help: "Shrink the mask to drop the rim of background color around the subject, or grow it",
                        hint: "Shrinks the mask to drop the rim of background color around the subject, or grows it.",
                        shown: { $0.backgroundQuality == .advanced })),
        ],
        .vignette: [
            .color(caption: "Color", help: "Choose the vignette color", hint: "Opens the color picker for the vignette.", value: \.vignetteColor,
                   open: { $0.openVignetteColorPicker() }),
            .slider(Row(caption: "Amount", key: \.vignetteAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Blend the chosen color into the edges while keeping the center unchanged",
                        hint: "Blends the chosen color into the edges, keeping the center unchanged.")),
            .slider(Row(caption: "Midpoint", key: \.vignetteMidpoint, range: 0...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Roundness", key: \.vignetteRoundness, range: -100...100, unit: nil, decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Feather", key: \.vignetteFeather, range: 0...100, unit: "%", decimals: 0, logarithmic: false)),
            .slider(Row(caption: "Highlights", key: \.vignetteHighlights, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "Protect bright areas near the edge", hint: "Protects bright areas near the edge.")),
        ],
        .gradientMap: [
            .gradient { settings in [settings.gradientMap.ends.dark, settings.gradientMap.ends.light] },
            .swatches([Swatch(title: "Shadows", value: \.gradientMap.shadows, open: { $0.openGradientMapColorPicker(highlights: false) }),
                       Swatch(title: "Highlights", value: \.gradientMap.highlights, open: { $0.openGradientMapColorPicker(highlights: true) })]),
            .checkbox("Reverse", \.gradientMap.reversed),
        ],
        // The rows each style uses, as the Mac's panel shows them.
        .dither: [
            .popUp(caption: "Style", groups: DitherStyle.groups.map { $0.map(\.rawValue) }, chosen: { $0.dither.style.rawValue },
                   choose: { settings, name in if let style = DitherStyle(rawValue: name) { settings.dither.style = style } }),
            .slider(Row(caption: "Pixel Size", key: \.dither.pixelSize, range: DitherSettings.pixelSizeRange, unit: "px", decimals: 0,
                        logarithmic: false, help: "Make each dithered pixel this many pixels across, for a chunky old-screen look",
                        hint: "Makes each dithered pixel this many pixels across, for a chunky old-screen look.",
                        shown: { $0.dither.style.usesPixelSize })),
            // Text Size's help says only what its caption does, so it has no hint.
            .slider(Row(caption: "Text Size", key: \.dither.textSize, range: DitherSettings.textSizeRange, unit: "px", decimals: 0,
                        logarithmic: false, help: "The height of each line of characters", shown: { $0.dither.style == .ascii })),
            .slider(Row(caption: "Cell Size", key: \.dither.cellSize, range: DitherSettings.cellSizeRange, unit: "px", decimals: 0,
                        logarithmic: false, shown: { $0.dither.style.isHalftone })),
            .slider(Row(caption: "Angle", key: \.dither.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false,
                        shown: { $0.dither.style.isHalftone })),
            .field(caption: "Characters", key: \.dither.characters,
                   help: "The characters to draw with, in any order: each spot gets the one whose ink best matches its tone",
                   hint: "Draws each spot with the one of these characters whose ink best matches its tone.",
                   shown: { $0.dither.style == .ascii }),
            .slider(Row(caption: "Tones", key: \.dither.levels, range: DitherSettings.levelsRange, unit: nil, decimals: 0, logarithmic: false,
                        help: "Tones per channel: 2 is pure black and white", hint: "Sets how many levels each channel has; 2 is pure black and white.",
                        shown: { $0.dither.style.hasTones })),
            .slider(Row(caption: "Diffusion", key: \.dither.diffusion, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        help: "How much of each pixel's error spreads to its neighbors. Less gives flatter areas",
                        hint: "Spreads each pixel's error to its neighbors; less gives flatter areas.",
                        shown: { $0.dither.style.diffuses })),
            .slider(Row(caption: "Density", key: \.dither.density, range: -100...100, unit: nil, decimals: 0, logarithmic: false,
                        help: "More ink (darker) or less before dithering", hint: "Darkens with more ink, or lightens with less, before dithering.")),
            .slider(Row(caption: "Contrast", key: \.dither.contrast, range: -100...100, unit: nil, decimals: 0, logarithmic: false)),
            .popUp(caption: "Colors", groups: [DitherColors.allCases.map(\.rawValue)], chosen: { $0.dither.colors.rawValue },
                   choose: { settings, name in if let colors = DitherColors(rawValue: name) { settings.dither.colors = colors } }),
            .swatches([Swatch(title: "Dark", value: \.dither.dark, open: { $0.openDitherColorPicker(light: false) }),
                       Swatch(title: "Light", value: \.dither.light, open: { $0.openDitherColorPicker(light: true) })],
                      titlesFirst: true, shown: { $0.dither.colors == .twoColors }),
            .popUp(caption: "Pixel Shape", groups: [DitherPixelShape.allCases.map(\.rawValue)],
                   help: "Draw each chunky pixel as a solid square, or as a round dot like a dot-matrix screen",
                   hint: "Draws each chunky pixel as a solid square, or as a round dot like a dot-matrix screen.",
                   chosen: { $0.dither.pixelShape.rawValue },
                   choose: { settings, name in if let shape = DitherPixelShape(rawValue: name) { settings.dither.pixelShape = shape } },
                   shown: { $0.dither.pixelSize > 1 && $0.dither.style.usesPixelSize }),
            .checkbox("Light on Dark", \.dither.lightOnDark, help: "Draw the marks for the light tones on the dark color, like a glowing screen",
                      hint: "Draws the marks for the light tones on the dark color, like a glowing screen.", shown: { $0.dither.style.drawsMarks }),
        ],
        // Each slider says how bright that family of colors becomes, as Photoshop's do.
        .blackWhite: [
            family("Reds", \.blackWhite.reds, hue: 0), family("Yellows", \.blackWhite.yellows, hue: 60),
            family("Greens", \.blackWhite.greens, hue: 120), family("Cyans", \.blackWhite.cyans, hue: 180),
            family("Blues", \.blackWhite.blues, hue: 240), family("Magentas", \.blackWhite.magentas, hue: 300),
            .checkbox("Tint", \.blackWhite.tint, help: "Color the result while keeping its tones, for a sepia or a cyanotype",
                      hint: "Colors the result while keeping its tones, for a sepia or a cyanotype."),
            .slider(Row(caption: "Hue", key: \.blackWhite.tintHue, range: 0...360, unit: "°", decimals: 0, logarithmic: false,
                        shown: { $0.blackWhite.tint }, track: { _ in .plain })),
            .slider(Row(caption: "Saturation", key: \.blackWhite.tintSaturation, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                        shown: { $0.blackWhite.tint }, track: { .saturation($0.blackWhite.tintHue) })),
        ],
        .colorBalance: [
            .heading("Shadows"),
            balance("Cyan / Red", \.colorBalance.shadowCyanRed, .cyanRed),
            balance("Magenta / Green", \.colorBalance.shadowMagentaGreen, .magentaGreen),
            balance("Yellow / Blue", \.colorBalance.shadowYellowBlue, .yellowBlue),
            .heading("Midtones"),
            balance("Cyan / Red", \.colorBalance.midCyanRed, .cyanRed),
            balance("Magenta / Green", \.colorBalance.midMagentaGreen, .magentaGreen),
            balance("Yellow / Blue", \.colorBalance.midYellowBlue, .yellowBlue),
            .heading("Highlights"),
            balance("Cyan / Red", \.colorBalance.highlightCyanRed, .cyanRed),
            balance("Magenta / Green", \.colorBalance.highlightMagentaGreen, .magentaGreen),
            balance("Yellow / Blue", \.colorBalance.highlightYellowBlue, .yellowBlue),
            .checkbox("Preserve Luminosity", \.colorBalance.preserveLuminosity,
                      help: "Put each pixel's brightness back afterwards, so only the color moves",
                      hint: "Puts each pixel's brightness back afterward, so only the color moves."),
        ],
        .lensCorrection: [
            .slider(Row(caption: "Remove Distortion", key: \.distortion, range: -100...100, unit: nil, decimals: 0, logarithmic: false)),
            .note("Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion)."),
        ],
        .cameraRaw: cameraRaw,
    ]

    nonisolated private static func palette(_ color: AdjustmentColor) -> PaletteColor {
        PaletteColor(red: color.red, green: color.green, blue: color.blue)
    }

    /// Black & White's row for a family of colors, its track dark to light in the family's hue.
    private static func family(_ caption: String, _ key: WritableKeyPath<FilterSettings, Double>, hue: Double) -> Control {
        .slider(Row(caption: caption, key: key, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false,
                    track: { _ in .luminance(hue) }))
    }
    /// Color Balance's row for a pair of colors, its track from one to the other.
    private static func balance(_ caption: String, _ key: WritableKeyPath<FilterSettings, Double>, _ track: CameraRawSliderTrack) -> Control {
        .slider(Row(caption: caption, key: key, range: ColorBalanceSettings.range, unit: nil, decimals: 0, logarithmic: false,
                    track: { _ in track }))
    }

    /// A Camera Raw row: its setting's range, and the colored track the Mac's panel gives it.
    private static func raw(_ caption: String, _ key: WritableKeyPath<FilterSettings, Double>,
                            _ range: ClosedRange<Double> = -100...100, unit: String? = nil, decimals: Int = 0,
                            help: String? = nil, track: CameraRawSliderTrack? = nil) -> Control {
        let trackClosure: ((FilterSettings) -> CameraRawSliderTrack)? = track.map { value in { _ in value } }
        return .slider(Row(caption: caption, key: key, range: range, unit: unit, decimals: decimals, logarithmic: false,
                           help: help, track: trackClosure))
    }

    /// Camera Raw's panel, section by section: the Mac folds these, while the iPad shows them all down one scroll.
    private static var cameraRaw: [Control] {
        var controls: [Control] = [
            .heading("Light"),
            raw("Exposure", \.cameraRaw.exposure, CameraRawSettings.exposureRange, decimals: 2,
                help: "Brightens or darkens the whole picture, in stops of light."),
            raw("Contrast", \.cameraRaw.contrast, help: "Makes light and dark tones more or less different, mostly around the middle."),
            raw("Highlights", \.cameraRaw.highlights, help: "Adjusts the bright parts of the picture."),
            raw("Shadows", \.cameraRaw.shadows, help: "Adjusts the dark parts of the picture."),
            raw("Whites", \.cameraRaw.whites, help: "Sets the brightest point."),
            raw("Blacks", \.cameraRaw.blacks, help: "Sets the darkest point."),

            .heading("Color"),
            .action("Auto White Balance", help: "Balance the average color of the picture",
                    hint: "Works out the white balance from the picture's own average color.") { session in
                Task { await session.applyCameraRawAutoWhiteBalance() }
            },
            raw("Temperature", \.cameraRaw.temperature, help: "Shifts the picture from blue to yellow.", track: .temperature),
            raw("Tint", \.cameraRaw.tint, help: "Shifts the picture from green to mauve.", track: .tint),
            raw("Vibrance", \.cameraRaw.vibrance,
                help: "Strengthens quiet colors more than colors that are already strong, and protects skin tones.", track: .chroma),
            raw("Saturation", \.cameraRaw.saturation, help: "Strengthens or weakens every color by the same amount.", track: .chroma),

            .heading("Effects"),
            raw("Texture", \.cameraRaw.texture, help: "Adds or softens small detail."),
            raw("Clarity", \.cameraRaw.clarity, help: "Adds or softens contrast along broader shapes."),
            raw("Dehaze", \.cameraRaw.dehaze, help: "Clears haze when raised, and adds haze when lowered."),
            .heading("Glow"),
            raw("Glow", \.cameraRaw.glow, CameraRawSettings.unitRange, help: "Spreads a glow from the bright areas."),
            .popUp(caption: "Style", groups: [CameraRawGlowStyle.allCases.map(\.rawValue)],
                   help: "Diffusion is soft and wide, Bloom is tighter, and Halation is a red fringe.",
                   hint: "The glow's look.", chosen: { $0.cameraRaw.glowStyle.rawValue },
                   choose: { settings, name in if let style = CameraRawGlowStyle(rawValue: name) { settings.cameraRaw.glowStyle = style } }),
            raw("Range", \.cameraRaw.glowRange, help: "Chooses how bright an area must be to glow. Has no effect until Glow is raised."),
            raw("Spread", \.cameraRaw.glowSpread, help: "Sets how far the glow reaches. Has no effect until Glow is raised."),
            raw("Warmth", \.cameraRaw.glowWarmth,
                help: "Shifts the glow from cool to warm. Halation stays red. Has no effect until Glow is raised."),
            .heading("Vignette"),
            raw("Amount", \.cameraRaw.vignetteAmount, help: "Darkens or lightens the edges. The center does not change."),
            .popUp(caption: "Style", groups: [CameraRawVignetteStyle.allCases.map(\.rawValue)],
                   help: "Highlight Priority protects bright edges. Color Priority also reduces color. Paint Overlay covers the edges evenly.",
                   hint: "How the vignette blends into the edges.", chosen: { $0.cameraRaw.vignetteStyle.rawValue },
                   choose: { settings, name in
                       if let style = CameraRawVignetteStyle(rawValue: name) { settings.cameraRaw.vignetteStyle = style }
                   }),
            raw("Midpoint", \.cameraRaw.vignetteMidpoint, CameraRawSettings.unitRange,
                help: "Sets where the vignette begins, from the center outward."),
            raw("Roundness", \.cameraRaw.vignetteRoundness, help: "Makes the vignette rounder or more square."),
            raw("Feather", \.cameraRaw.vignetteFeather, CameraRawSettings.unitRange, help: "Softens the edge of the vignette."),
            raw("Highlights", \.cameraRaw.vignetteHighlights, CameraRawSettings.unitRange,
                help: "Protects bright pixels while a dark vignette is applied. Used by Highlight Priority."),
            .heading("Grain"),
            raw("Amount", \.cameraRaw.grainAmount, CameraRawSettings.unitRange, help: "Adds film grain, strongest in the middle tones."),
            raw("Size", \.cameraRaw.grainSize, CameraRawSettings.unitRange, help: "Makes the grain coarser or finer."),
            raw("Roughness", \.cameraRaw.grainRoughness, CameraRawSettings.unitRange, help: "Makes the grain smoother or more uneven."),

            .heading("Curve"),
            .popUp(caption: "Point Curve", groups: [["Linear", "Medium Contrast", "Strong Contrast", "Custom"]],
                   help: "Shapes the tones with the curve's points", hint: "Puts the curve's points to a preset.",
                   chosen: { curveName($0.cameraRaw.curve.rgb) },
                   choose: { settings, name in
                       switch name {
                       case "Medium Contrast": settings.cameraRaw.curve.rgb = CameraRawCurveSettings.mediumContrast
                       case "Strong Contrast": settings.cameraRaw.curve.rgb = CameraRawCurveSettings.strongContrast
                       case "Linear": settings.cameraRaw.curve.rgb = CameraRawCurveSettings.linear
                       default: break
                       }
                   }),
            raw("Shadows", \.cameraRaw.curve.shadows, help: "Bends the tones below the first split."),
            raw("Darks", \.cameraRaw.curve.darks, help: "Bends the tones below the middle split."),
            raw("Lights", \.cameraRaw.curve.lights, help: "Bends the tones above the middle split."),
            raw("Highlights", \.cameraRaw.curve.highlights, help: "Bends the tones above the last split."),
            raw("Shadow Split", \.cameraRaw.curve.shadowSplit, CameraRawSettings.unitRange, help: "Where Shadows hands off to Darks."),
            raw("Dark Split", \.cameraRaw.curve.darkSplit, CameraRawSettings.unitRange, help: "Where Darks hands off to Lights."),
            raw("Light Split", \.cameraRaw.curve.lightSplit, CameraRawSettings.unitRange, help: "Where Lights hands off to Highlights."),
            raw("Refine Saturation", \.cameraRaw.curve.refineSaturation,
                help: "How much the curve also changes color strength. Zero matches Photoshop; lower keeps it to brightness, higher adds more color."),
        ]

        let hues: [WritableKeyPath<FilterSettings, Double>] = [
            \.cameraRaw.mixer.hue[0], \.cameraRaw.mixer.hue[1], \.cameraRaw.mixer.hue[2], \.cameraRaw.mixer.hue[3],
            \.cameraRaw.mixer.hue[4], \.cameraRaw.mixer.hue[5], \.cameraRaw.mixer.hue[6], \.cameraRaw.mixer.hue[7],
        ]
        let saturations: [WritableKeyPath<FilterSettings, Double>] = [
            \.cameraRaw.mixer.saturation[0], \.cameraRaw.mixer.saturation[1], \.cameraRaw.mixer.saturation[2],
            \.cameraRaw.mixer.saturation[3], \.cameraRaw.mixer.saturation[4], \.cameraRaw.mixer.saturation[5],
            \.cameraRaw.mixer.saturation[6], \.cameraRaw.mixer.saturation[7],
        ]
        let luminances: [WritableKeyPath<FilterSettings, Double>] = [
            \.cameraRaw.mixer.luminance[0], \.cameraRaw.mixer.luminance[1], \.cameraRaw.mixer.luminance[2],
            \.cameraRaw.mixer.luminance[3], \.cameraRaw.mixer.luminance[4], \.cameraRaw.mixer.luminance[5],
            \.cameraRaw.mixer.luminance[6], \.cameraRaw.mixer.luminance[7],
        ]
        controls.append(.heading("Color Mixer"))
        for index in CameraRawMixerSettings.names.indices {
            controls.append(.heading(CameraRawMixerSettings.names[index]))
            controls += [raw("Hue", hues[index], help: "Shifts this color family's hue."),
                         raw("Saturation", saturations[index], help: "Strengthens or weakens this color family."),
                         raw("Luminance", luminances[index], help: "Lightens or darkens this color family.")]
        }

        controls += gradingWheel("Shadows", \.cameraRaw.grading.shadows)
        controls += gradingWheel("Midtones", \.cameraRaw.grading.midtones)
        controls += gradingWheel("Highlights", \.cameraRaw.grading.highlights)
        controls += gradingWheel("Global", \.cameraRaw.grading.global)
        controls += [
            raw("Blending", \.cameraRaw.grading.blending, CameraRawSettings.unitRange,
                help: "Controls how much the three tonal wheels overlap."),
            raw("Balance", \.cameraRaw.grading.balance, help: "Shifts the wheels toward shadows or highlights."),

            .heading("Detail"),
            raw("Sharpening", \.cameraRaw.detail.sharpenAmount, CameraRawDetailSettings.sharpenAmountRange, help: "Adds or softens sharpening."),
            raw("Radius", \.cameraRaw.detail.sharpenRadius, CameraRawDetailSettings.unitRange, help: "How fine the sharpened detail is."),
            raw("Detail", \.cameraRaw.detail.sharpenDetail, CameraRawDetailSettings.unitRange,
                help: "How much fine texture is sharpened, beyond the edges."),
            raw("Masking", \.cameraRaw.detail.sharpenMasking, CameraRawDetailSettings.unitRange,
                help: "Keeps sharpening to the edges, leaving even areas smooth."),
            .heading("Noise Reduction"),
            raw("Luminance", \.cameraRaw.detail.noiseLuminance, CameraRawDetailSettings.unitRange,
                help: "Smooths grain from the picture's brightness."),
            raw("Luminance Detail", \.cameraRaw.detail.noiseLuminanceDetail, CameraRawDetailSettings.unitRange,
                help: "How much fine texture is kept while the grain is smoothed."),
            raw("Luminance Contrast", \.cameraRaw.detail.noiseLuminanceContrast, CameraRawDetailSettings.unitRange,
                help: "How much contrast is kept while the grain is smoothed."),
            raw("Color", \.cameraRaw.detail.noiseColor, CameraRawDetailSettings.unitRange,
                help: "Smooths colored speckle into the colors around it."),
            raw("Color Detail", \.cameraRaw.detail.noiseColorDetail, CameraRawDetailSettings.unitRange,
                help: "How much fine color detail is kept."),
            raw("Color Smoothness", \.cameraRaw.detail.noiseColorSmoothness, CameraRawDetailSettings.unitRange,
                help: "How smoothly the color is smoothed."),

            .heading("Optics"),
            .checkbox("Remove Chromatic Aberration", \.cameraRaw.optics.removeChromaticAberration,
                      help: "Pull the color fringes off high-contrast edges"),
            .checkbox("Enable Lens Profile", \.cameraRaw.optics.enableLensProfile,
                      help: "Correct distortion and falloff as a lens profile would"),
            raw("Profile Distortion", \.cameraRaw.optics.profileDistortion, CameraRawSettings.unitRange,
                help: "How much of the lens profile's distortion correction to apply."),
            raw("Profile Vignetting", \.cameraRaw.optics.profileVignetting, CameraRawSettings.unitRange,
                help: "How much of the lens profile's vignetting correction to apply."),
            raw("Distortion", \.cameraRaw.optics.distortion, help: "Straightens barrel or pincushion distortion by hand."),
            raw("Purple Amount", \.cameraRaw.optics.purpleAmount, CameraRawSettings.unitRange,
                help: "How much purple fringing is removed."),
            raw("Purple Hue Low", \.cameraRaw.optics.purpleHueLow, 0...360, unit: "°", help: "The lower edge of the fringe's hue range."),
            raw("Purple Hue High", \.cameraRaw.optics.purpleHueHigh, 0...360, unit: "°", help: "The upper edge of the fringe's hue range."),
            raw("Green Amount", \.cameraRaw.optics.greenAmount, CameraRawSettings.unitRange,
                help: "How much green fringing is removed."),
            raw("Green Hue Low", \.cameraRaw.optics.greenHueLow, 0...360, unit: "°", help: "The lower edge of the fringe's hue range."),
            raw("Green Hue High", \.cameraRaw.optics.greenHueHigh, 0...360, unit: "°", help: "The upper edge of the fringe's hue range."),
            raw("Vignette Amount", \.cameraRaw.optics.vignetteAmount, help: "Brightens the corners to counter lens falloff."),
            raw("Vignette Midpoint", \.cameraRaw.optics.vignetteMidpoint, CameraRawSettings.unitRange,
                help: "Where the falloff correction begins, from the center outward."),

            .heading("Geometry"),
            .popUp(caption: "Upright", groups: [CameraRawUprightMode.allCases.map(\.rawValue)],
                   help: "Guided straightens the lines drawn on the picture", hint: "Automatic or guided straightening.",
                   chosen: { $0.cameraRaw.geometry.upright.rawValue },
                   choose: { settings, name in
                       if let mode = CameraRawUprightMode(rawValue: name) { settings.cameraRaw.geometry.upright = mode }
                   }),
            .popUp(caption: "Projection", groups: [CameraRawProjection.allCases.map(\.rawValue)],
                   chosen: { $0.cameraRaw.geometry.projection.rawValue },
                   choose: { settings, name in
                       if let projection = CameraRawProjection(rawValue: name) { settings.cameraRaw.geometry.projection = projection }
                   }),
            raw("Vertical", \.cameraRaw.geometry.vertical, help: "Straightens converging vertical lines."),
            raw("Horizontal", \.cameraRaw.geometry.horizontal, help: "Straightens converging horizontal lines."),
            raw("Rotate", \.cameraRaw.geometry.rotate, CameraRawGeometrySettings.rotateRange, unit: "°",
                help: "Turns the picture to level it."),
            raw("Aspect", \.cameraRaw.geometry.aspect, help: "Stretches the picture side to side."),
            raw("Scale", \.cameraRaw.geometry.scale, help: "Fills the frame after the other geometry changes."),
            raw("Offset X", \.cameraRaw.geometry.offsetX, help: "Moves the picture sideways."),
            raw("Offset Y", \.cameraRaw.geometry.offsetY, help: "Moves the picture up or down."),
            .checkbox("Constrain Crop", \.cameraRaw.geometry.constrainCrop,
                      help: "Trim the empty edges the geometry leaves behind"),

            .heading("Calibration"),
            .popUp(caption: "Process", groups: [CameraRawProcessVersion.allCases.map(\.rawValue)],
                   help: "The color process the calibration follows", hint: "The color process version.",
                   chosen: { $0.cameraRaw.calibration.process.rawValue },
                   choose: { settings, name in
                       if let process = CameraRawProcessVersion(rawValue: name) { settings.cameraRaw.calibration.process = process }
                   }),
            raw("Shadow Tint", \.cameraRaw.calibration.shadowTint, help: "Shifts the shadows from green to magenta."),
            raw("Red Hue", \.cameraRaw.calibration.redHue, help: "Shifts the red primary's hue."),
            raw("Red Saturation", \.cameraRaw.calibration.redSaturation, help: "Strengthens or weakens the red primary."),
            raw("Green Hue", \.cameraRaw.calibration.greenHue, help: "Shifts the green primary's hue."),
            raw("Green Saturation", \.cameraRaw.calibration.greenSaturation, help: "Strengthens or weakens the green primary."),
            raw("Blue Hue", \.cameraRaw.calibration.blueHue, help: "Shifts the blue primary's hue."),
            raw("Blue Saturation", \.cameraRaw.calibration.blueSaturation, help: "Strengthens or weakens the blue primary."),
        ]
        return controls
    }

    /// One of Color Grading's wheels, as its three settings.
    private static func gradingWheel(_ title: String, _ base: WritableKeyPath<FilterSettings, CameraRawGradeWheel>) -> [Control] {
        [.heading(title),
         raw("Hue", base.appending(path: \CameraRawGradeWheel.hue), 0...360, unit: "°", help: "The color this tonal range takes."),
         raw("Saturation", base.appending(path: \CameraRawGradeWheel.saturation), CameraRawSettings.unitRange,
             help: "How strongly this tonal range takes the color.", track: .spectrum(0)),
         raw("Luminance", base.appending(path: \CameraRawGradeWheel.luminance), help: "Lightens or darkens this tonal range.")]
    }

    private static func curveName(_ points: [CurvePoint]) -> String {
        if CameraRawCurveSettings.isLinear(points) { return "Linear" }
        if points == CameraRawCurveSettings.mediumContrast { return "Medium Contrast" }
        if points == CameraRawCurveSettings.strongContrast { return "Strong Contrast" }
        return "Custom"
    }

    /// The kinds the iPad has this editor for; the Filter and Image menus offer them, and New Adjustment Layer the
    /// adjustments among them. Rim Light has an editor of its own, for its lights.
    static let kinds = Set(controls.keys).union([.rimLight])

    /// Each kind's slider rows, in order.
    static let rows: [FilterKind: [Row]] = controls.mapValues { controls in
        controls.compactMap { if case .slider(let row) = $0 { row } else { nil } }
    }

    let kind: FilterKind
    private var fields: [(row: Row, field: SliderField)] = []
    /// Why the preview couldn't be made, in orange, as the Mac's panel says it.
    private let error = OptionControls.caption("", color: .systemOrange)
    /// Puts the edit's values into the controls other than sliders.
    private var refreshers: [(FilterSettings) -> Void] = []

    init(session: EditorSession, kind: FilterKind) {
        self.kind = kind
        super.init(session: session, title: kind.displayName)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var edit: FilterEdit? { session.filterEdit }
    private func update(_ change: (inout FilterSettings) -> Void) {
        guard var settings = edit?.settings else { return }
        change(&settings)
        session.updateFilter(settings, preview: edit?.preview ?? true)
    }

    override var isOpen: Bool { edit?.kind == kind }
    override var previews: Bool { edit?.preview ?? true }
    override func setPreview(_ on: Bool) {
        guard let edit else { return }
        session.updateFilter(edit.settings, preview: on)
    }
    override func cancel() { session.cancelFilter() }
    override func commit() {
        // OK waits for a slow filter's preview, as the Mac's disabled OK does; Return with it.
        guard canCommit else { return }
        let session = session
        Task { await session.commitFilter() }
    }
    override var canCommit: Bool {
        guard let edit else { return false }
        return !(kind.isAutomatic && (edit.preparing || edit.previewError != nil))
    }
    /// Applying… while OK applies the filter; Working… while a slow one (Remove Background, Content-Aware Fill) works out
    /// its preview, as the Mac's panel says. A quick one says nothing, so the panel doesn't flicker as a slider moves.
    override var activity: Activity? {
        guard let edit else { return nil }
        if edit.committing { return Activity(text: "Applying…", holds: true) }
        if edit.preparing, kind.isAutomatic { return Activity(text: "Working…", holds: false) }
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        var captions: [UILabel] = []
        /// Adds `view` to the controls, showing only while `shown` says so.
        func add(_ view: UIView, shown: ((FilterSettings) -> Bool)?) {
            content.addArrangedSubview(view)
            if let shown { refreshers.append { view.isHidden = !shown($0) } }
        }
        for control in Self.controls[kind] ?? [] {
            switch control {
            case .slider(let row):
                let step = pow(10, Double(row.decimals))
                let field = SliderField(caption: row.caption, unit: row.unit, sliderRange: row.range, fieldRange: row.range,
                                        sensitivity: 1 / step, logarithmic: row.logarithmic, decimals: row.decimals, sliderWidth: nil,
                                        fieldWidth: NumberField.width(toShow: row.range, decimals: row.decimals))
                field.onChange = { [weak self] value in self?.update { $0[keyPath: row.key] = value } }
                field.setHelp(row.help, hint: row.hint)
                if row.track != nil {
                    field.onReset = { [weak self] in self?.update { $0[keyPath: row.key] = FilterSettings()[keyPath: row.key] } }
                    // VoiceOver has Reset among the slider's actions, so that's no hint.
                    field.setHelp(row.help ?? row.caption + ". Double-click to reset.", hint: row.hint)
                }
                fields.append((row, field))
                content.addArrangedSubview(field)
            case .choice(let caption, let titles, let help, let hints, let chosen, let choose, let shown):
                let segments = OptionControls.segments(titles) { [weak self] index in self?.update { choose(&$0, index) } }
                segments.setHelp(help, hints: hints ?? [])
                refreshers.append { segments.selectedSegmentIndex = chosen($0) }
                let views = (caption.map { [OptionControls.caption($0, color: .secondaryLabel)] } ?? []) + [segments, UIView()]
                add(OptionControls.row(views, spacing: 10), shown: shown)
            case .popUp(let caption, let groups, let help, let hint, let chosen, let choose, let shown):
                let popUp = PopUpButton()
                popUp.accessibilityLabel = caption
                popUp.setHelp(help, hint: hint)
                popUp.onChoose = { [weak self] name in self?.update { choose(&$0, name) } }
                refreshers.append { popUp.show(groups, chosen: chosen($0)) }
                add(OptionControls.row([OptionControls.caption(caption, color: .secondaryLabel), popUp, UIView()], spacing: 10), shown: shown)
            case .checkbox(let title, let key, let help, let hint, let shown):
                let box = OptionControls.checkbox(title) { [weak self] on in self?.update { $0[keyPath: key] = on } }
                box.setHelp(help, hint: hint)
                refreshers.append { box.isSelected = $0[keyPath: key] }
                add(OptionControls.row([box, UIView()]), shown: shown)
            case .field(let caption, let key, let help, let hint, let shown):
                let field = UITextField()
                field.borderStyle = .roundedRect
                field.font = .monospacedSystemFont(ofSize: OptionControls.controlFont.pointSize, weight: .regular)
                field.autocorrectionType = .no
                field.autocapitalizationType = .none
                field.spellCheckingType = .no
                field.accessibilityLabel = caption
                field.setHelp(help, hint: hint)
                field.addAction(UIAction { [weak self, weak field] _ in
                    guard let text = field?.text else { return }
                    self?.update { $0[keyPath: key] = text }
                }, for: .editingChanged)
                // Return only ends the typing, as in the Mac's field.
                field.addAction(UIAction { _ in }, for: .editingDidEndOnExit)
                refreshers.append { if !field.isEditing { field.text = $0[keyPath: key] } }
                add(OptionControls.row([OptionControls.caption(caption, color: .secondaryLabel), field], spacing: 10), shown: shown)
            case .color(let caption, let help, let hint, let value, let open):
                let label = OptionControls.caption(caption, color: .secondaryLabel)
                let swatch = SwatchButton(size: CGSize(width: 24, height: 24), cornerRadius: 6)
                swatch.accessibilityLabel = caption
                swatch.setHelp(help, hint: hint)
                swatch.addAction(UIAction { [weak self, weak swatch] _ in
                    guard let self else { return }
                    self.pickerSource = swatch
                    open(self.session)
                }, for: .primaryActionTriggered)
                refreshers.append { swatch.color = Self.palette(value($0)) }
                captions.append(label)
                // Spaced as a row's slider is from its caption, so the swatch starts where the sliders do.
                content.addArrangedSubview(OptionControls.row([label, swatch, UIView()], spacing: 8))
            case .gradient(let colors):
                let bar = GradientBar(height: 20)
                bar.layer.cornerRadius = 4
                bar.layer.cornerCurve = .continuous
                bar.layer.borderWidth = 1
                bar.layer.borderColor = UIColor.black.withAlphaComponent(0.35).cgColor
                bar.clipsToBounds = true
                refreshers.append { bar.colors = colors($0).map(Self.palette) }
                content.addArrangedSubview(bar)
            case .swatches(let ends, let titlesFirst, let shown):
                let pairs = ends.map { end -> UIView in
                    let swatch = SwatchButton(size: CGSize(width: 24, height: 24), cornerRadius: 6)
                    swatch.accessibilityLabel = end.title + " color"
                    swatch.setHelp("Choose the \(end.title.lowercased()) color", hint: "Opens the color picker.")
                    swatch.addAction(UIAction { [weak self, weak swatch] _ in
                        guard let self else { return }
                        self.pickerSource = swatch
                        end.open(self.session)
                    }, for: .primaryActionTriggered)
                    refreshers.append { swatch.color = Self.palette(end.value($0)) }
                    let title = OptionControls.caption(end.title, color: .label)
                    return OptionControls.row(titlesFirst ? [title, swatch] : [swatch, title], spacing: 8)
                }
                add(OptionControls.row(pairs + [UIView()], spacing: titlesFirst ? 18 : 20), shown: shown)
            case .heading(let title):
                let label = OptionControls.caption(title, color: .label)
                label.font = .preferredFont(forTextStyle: .headline)
                content.addArrangedSubview(label)
            case .text(let text):
                let label = OptionControls.caption(text, color: .label)
                label.numberOfLines = 0
                content.addArrangedSubview(label)
            case .action(let title, let help, let hint, let run):
                let button = OptionControls.button(title) { [weak self] in
                    guard let self else { return }
                    run(self.session)
                }
                button.setHelp(help, hint: hint)
                content.addArrangedSubview(OptionControls.row([button, UIView()]))
            case .note(let text, let shown):
                let note = OptionControls.caption(text, color: .secondaryLabel)
                note.numberOfLines = 0
                add(note, shown: shown)
            }
        }
        SliderField.alignColumns(fields.map(\.field), with: captions)
        error.numberOfLines = 0
        notes.insertArrangedSubview(error, at: 0)
    }

    override func refresh() {
        guard let settings = edit?.settings else { return }
        for (row, field) in fields {
            field.show(settings[keyPath: row.key])
            field.isHidden = row.shown?(settings) == false
            if let track = row.track { field.track = track(settings) }
        }
        for refresh in refreshers { refresh(settings) }
        error.text = edit?.previewError
        error.isHidden = edit?.previewError == nil
    }
}

private extension BackgroundQuality {
    /// What choosing it does, as VoiceOver's hint says it on its segment.
    var hint: String {
        switch self {
        case .basic: "Makes a quick mask."
        case .advanced: "Refines the mask against the layer's own detail, for hair and fur."
        }
    }
}

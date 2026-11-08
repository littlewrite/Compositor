import AppKit
import Testing
@testable import Compositor

@MainActor
struct FinishingFilterTests {
    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: try #require(context.data).assumingMemoryBound(to: UInt8.self),
                                         count: image.width * image.height * 4))
    }

    private func apply(_ kind: FilterKind, to source: CGImage, settings: FilterSettings) throws -> [UInt8] {
        let image = try PixelFilter.run(FilterJob(kind: kind, image: source, settings: settings,
                                                  scale: 1, selection: nil, mapping: .identity))
        return try pixels(image)
    }

    @Test func vignetteDarkensCornersWhileKeepingCenterAndAlpha() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.8, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 41, height: 41))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.vignetteAmount = 80
        let result = try apply(.vignette, to: source, settings: settings)
        let corner = 0, center = (20 * 41 + 20) * 4
        #expect(Int(result[center]) > Int(result[corner]) + 50)
        #expect(abs(Int(result[center]) - 204) <= 2)
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func vignetteBlendsSelectedColorOnlyAtEdges() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 41, height: 41))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.vignetteAmount = 100
        settings.vignetteHighlights = 0
        settings.vignetteColor = AdjustmentColor(red: 1, green: 0, blue: 0)
        let result = try apply(.vignette, to: source, settings: settings)
        let corner = 0, center = (20 * 41 + 20) * 4
        #expect(Int(result[corner]) > Int(result[corner + 1]) + 80)
        #expect(abs(Int(result[center]) - Int(result[center + 1])) <= 2)
        #expect(abs(Int(result[center]) - 128) <= 2)
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func bloomSpreadsLightFromBrightPixels() throws {
        let context = try BrushRaster.context(width: 65, height: 65, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 65, height: 65))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 30, y: 30, width: 5, height: 5))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.bloomAmount = 100
        settings.bloomRadius = 12
        let result = try apply(.bloomGlow, to: source, settings: settings)
        let nearLight = (32 * 65 + 40) * 4
        let corner = (2 * 65 + 2) * 4
        #expect(result[nearLight] > result[corner])
        #expect(result[nearLight] > 0)
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })

        let transparent = try BrushRaster.context(width: 65, height: 65, mask: false)
        transparent.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        transparent.fill(CGRect(x: 30, y: 30, width: 5, height: 5))
        let isolatedLight = try #require(transparent.makeImage())
        let spread = try apply(.bloomGlow, to: isolatedLight, settings: settings)
        #expect(spread[nearLight + 3] > 0, "bloom must remain visible beyond a transparent layer's bright pixels")
    }

    @Test func tonalContrastIncreasesMidtoneDetailWithoutChangingAlpha() throws {
        let context = try BrushRaster.context(width: 64, height: 16, mask: false)
        for stripe in 0..<8 {
            let gray: CGFloat = stripe.isMultiple(of: 2) ? 0.4 : 0.6
            context.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
            context.fill(CGRect(x: stripe * 8, y: 0, width: 8, height: 16))
        }
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        var settings = FilterSettings()
        settings.tonalAmount = 100
        settings.tonalShadows = 0
        settings.tonalMidtones = 100
        settings.tonalHighlights = 0
        settings.tonalRadius = 6
        let result = try apply(.tonalContrast, to: source, settings: settings)
        let dark = (8 * 64 + 5) * 4, light = (8 * 64 + 13) * 4
        #expect(result[dark] < original[dark])
        #expect(result[light] > original[light])
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    /// The Photoshop filters added for parity all run, keep the layer's size, and change the picture.
    @Test(arguments: [
        FilterKind.brightnessContrast, .shadowsHighlights, .vibrance, .posterize, .threshold, .channelMixer, .photoFilter,
        .mosaic, .crystallize, .colorHalftone, .twirl, .pinch, .spherize, .vortex, .gloom, .kaleidoscope,
        .pointillize, .hexagonalPixelate, .hole, .circleSplash, .torusLens,
        .boxBlur, .zoomBlur, .bokehBlur, .photoEffect,
        .findEdges, .comic, .lineScreen, .circularScreen, .hatchedScreen, .glass, .glassLozenge,
        .triangleKaleidoscope, .falseColor, .monochrome, .discBlur,
        .lensFlare, .lightTunnel, .solarize, .offset,
        .selectiveColor, .replaceColor,
        .tiltShiftBlur, .irisBlur,
        .fieldBlur, .spinBlur, .pathBlur,
        .clouds, .differenceClouds,
        .wave, .ripple,
    ])
    func newFiltersChangeThePicture(_ kind: FilterKind) throws {
        let context = try BrushRaster.context(width: 32, height: 32, mask: false)
        for x in 0..<32 {
            let level = CGFloat(x) / 31
            context.setFillColor(CGColor(srgbRed: level, green: 1 - level, blue: 0.5, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 32))
        }
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        var settings = FilterSettings()
        switch kind {
        case .brightnessContrast: settings.brightnessContrast.brightness = 40
        case .shadowsHighlights: settings.shadowsHighlights.shadows = 60
        case .channelMixer:
            settings.channelMixer.redFromRed = 0
            settings.channelMixer.redFromGreen = 100
            settings.channelMixer.greenFromRed = 100
            settings.channelMixer.greenFromGreen = 0
        case .photoFilter: settings.photoFilterDensity = 80
        case .vibrance: settings.vibranceAmount = 80
        case .posterize: settings.posterizeLevels = 3
        case .threshold: settings.thresholdLevel = 128
        case .mosaic: settings.mosaicCellSize = 8
        case .crystallize: settings.crystallizeSize = 8
        case .colorHalftone: settings.halftoneWidth = 8
        case .twirl: settings.twirlAngle = 120
        case .pinch: settings.pinchAmount = 80
        case .spherize: settings.spherizeAmount = 80
        case .vortex: settings.vortexAngle = 120
        case .gloom: settings.gloomRadius = 6; settings.gloomIntensity = 80
        case .kaleidoscope: settings.kaleidoscopeCount = 6
        case .pointillize: settings.pointillizeSize = 8
        case .hexagonalPixelate: settings.hexagonalPixelateSize = 8
        case .hole: settings.holeRadius = 20
        case .circleSplash: settings.circleSplashRadius = 20
        case .torusLens: settings.torusLensRadius = 16; settings.torusLensWidth = 6; settings.torusLensRefraction = 1.5
        case .boxBlur: settings.boxBlurRadius = 8
        case .zoomBlur: settings.zoomAmount = 50
        case .bokehBlur: settings.bokehRadius = 8; settings.bokehRingAmount = 50
        case .photoEffect: settings.photoEffect = .noir
        case .findEdges: settings.edgesIntensity = 4
        case .lineScreen, .circularScreen, .hatchedScreen: settings.halftoneWidth = 8
        case .glass: settings.glassScale = 120
        case .glassLozenge: settings.glassLensRadius = 24; settings.glassRefraction = 1.8
        case .triangleKaleidoscope: settings.triangleKaleidoscopeSize = 40; settings.triangleKaleidoscopeRotation = 30
        case .falseColor: settings.falseColorPalette = .thermal
        case .monochrome: settings.monochromeTint = .sepia; settings.monochromeAmount = 100
        case .discBlur: settings.discBlurRadius = 10
        case .lensFlare: settings.lensFlareBrightness = 120; settings.lensFlareSize = 40
        case .lightTunnel: settings.lightTunnelRadius = 10; settings.lightTunnelRotation = 90
        case .solarize: settings.solarizeThreshold = 128
        case .offset: settings.offsetX = 8; settings.offsetY = 5
        case .selectiveColor: settings.selectiveReds.cyan = 60; settings.selectiveBlues.yellow = 60
        case .replaceColor: settings.replaceTargetHue = 0; settings.replaceTolerance = 90; settings.replaceHue = 120
        case .tiltShiftBlur: settings.tiltShiftRadius = 8; settings.tiltShiftBand = 10
        case .irisBlur: settings.irisBlurRadius = 8; settings.irisRadius = 6; settings.irisFeather = 100
        case .fieldBlur: settings.fieldBlurRadius = 8; settings.fieldReach = 60
        case .spinBlur: settings.spinAmount = 30
        case .pathBlur: settings.pathDistance = 10; settings.pathCurve = 20
        case .clouds, .differenceClouds: settings.cloudsScale = 24; settings.cloudsDetail = 50
        case .wave, .ripple: settings.waveAmplitude = 12; settings.waveLength = 16
        default: break
        }
        let result = try apply(kind, to: source, settings: settings)
        #expect(result.count == original.count, "\(kind.rawValue) kept the layer's size")
        #expect(result != original, "\(kind.rawValue) changed the picture")
    }

    @Test func brightnessContrastLiftsMidtones() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        var settings = FilterSettings()
        settings.brightnessContrast.brightness = 50
        let result = try apply(.brightnessContrast, to: source, settings: settings)
        #expect(result[0] > original[0] + 20)
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func posterizeKeepsFewLevels() throws {
        let context = try BrushRaster.context(width: 64, height: 8, mask: false)
        for x in 0..<64 {
            let level = CGFloat(x) / 63
            context.setFillColor(CGColor(srgbRed: level, green: level, blue: level, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 8))
        }
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.posterizeLevels = 4
        let result = try apply(.posterize, to: source, settings: settings)
        let reds = Set((0..<64).map { result[$0 * 4] })
        #expect(reds.count <= 4, "posterize kept \(reds.count) levels")
    }

    @Test func thresholdSplitsOnBrightness() throws {
        let context = try BrushRaster.context(width: 16, height: 8, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.8, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 8, y: 0, width: 8, height: 8))
        let source = try #require(context.makeImage())
        let result = try apply(.threshold, to: source, settings: FilterSettings())
        #expect(result[4] <= 2, "the dark half becomes black")
        #expect(result[(8 + 4) * 4] >= 253, "the bright half becomes white")
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func mosaicMakesBlocksOfOneColor() throws {
        let context = try BrushRaster.context(width: 64, height: 8, mask: false)
        for x in 0..<64 {
            let level = CGFloat(x) / 63
            context.setFillColor(CGColor(srgbRed: level, green: level, blue: level, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 8))
        }
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.mosaicCellSize = 8
        let result = try apply(.mosaic, to: source, settings: settings)
        let reds = Set((0..<64).map { result[$0 * 4] })
        #expect(reds.count <= 10, "mosaic left \(reds.count) colors across 8 blocks")
    }

    @Test func medianRemovesSpeckle() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 7, y: 7, width: 2, height: 2))
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        let result = try apply(.median, to: source, settings: FilterSettings())
        let center = (8 * 16 + 8) * 4
        #expect(original[center] == 255)
        #expect(result[center] < 60, "the speckle is gone: \(result[center])")
    }

    @Test func desaturateMakesEveryPixelGray() throws {
        let context = try BrushRaster.context(width: 24, height: 8, mask: false)
        let colors = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
        for (index, color) in colors.enumerated() {
            context.setFillColor(CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
            context.fill(CGRect(x: index * 8, y: 0, width: 8, height: 8))
        }
        let source = try #require(context.makeImage())
        let result = try apply(.desaturate, to: source, settings: FilterSettings())
        for x in stride(from: 4, to: 24, by: 8) {
            let offset = (4 * 24 + x) * 4
            #expect(result[offset] == result[offset + 1] && result[offset + 1] == result[offset + 2], "pixel \(x) is gray")
        }
    }

    @Test func autoContrastStretchesALowContrastPicture() throws {
        let context = try BrushRaster.context(width: 64, height: 8, mask: false)
        for x in 0..<64 {
            let level = 0.3 + CGFloat(x) / 63 * 0.4
            context.setFillColor(CGColor(srgbRed: level, green: level, blue: level, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 8))
        }
        let source = try #require(context.makeImage())
        let result = try apply(.autoContrast, to: source, settings: FilterSettings())
        #expect(result[4] <= 8, "the dark end becomes black: \(result[4])")
        #expect(result[63 * 4] >= 247, "the bright end becomes white: \(result[63 * 4])")
    }

    @Test func equalizeSpreadsTheTones() throws {
        let context = try BrushRaster.context(width: 16, height: 8, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.8, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 8, y: 0, width: 8, height: 8))
        let source = try #require(context.makeImage())
        let result = try apply(.equalize, to: source, settings: FilterSettings())
        let left = (4 * 16 + 4) * 4, right = (4 * 16 + 12) * 4
        #expect(result[left] <= 8 && result[right] >= 247, "the two tones reach both ends: \(result[left]) and \(result[right])")
    }

    @Test(arguments: [FilterKind.autoTone, .autoColor])
    func automaticColorAdjustmentsChangeThePicture(_ kind: FilterKind) throws {
        let context = try BrushRaster.context(width: 32, height: 16, mask: false)
        for x in 0..<32 {
            let level = 0.35 + CGFloat(x) / 31 * 0.3
            context.setFillColor(CGColor(srgbRed: level, green: level * 0.8, blue: level * 0.6, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 16))
        }
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        let result = try apply(kind, to: source, settings: FilterSettings())
        #expect(result != original)
    }

    @Test func channelMixerSwapsTheChannels() throws {
        let context = try BrushRaster.context(width: 16, height: 8, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 8, y: 0, width: 8, height: 8))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.channelMixer.redFromRed = 0
        settings.channelMixer.redFromGreen = 100
        settings.channelMixer.greenFromRed = 100
        settings.channelMixer.greenFromGreen = 0
        let result = try apply(.channelMixer, to: source, settings: settings)
        let left = (4 * 16 + 4) * 4, right = (4 * 16 + 12) * 4
        #expect(result[left + 1] >= 250 && result[left] <= 5, "red became green: \(result[left]), \(result[left + 1])")
        #expect(result[right] >= 250 && result[right + 1] <= 5, "green became red: \(result[right]), \(result[right + 1])")
    }

    @Test func photoFilterWarmsAGrayPicture() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.photoFilterPreset = .warming85
        settings.photoFilterDensity = 100
        let result = try apply(.photoFilter, to: source, settings: settings)
        #expect(result[0] > result[2] + 20, "the warm tint shows: \(result[0]) vs \(result[2])")
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func findEdgesLeavesAWhiteGround() throws {
        let context = try BrushRaster.context(width: 32, height: 32, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let source = try #require(context.makeImage())
        let result = try apply(.findEdges, to: source, settings: FilterSettings())
        let center = (16 * 32 + 16) * 4
        #expect(result[center] >= 250, "a flat picture leaves white: \(result[center])")
    }

    @Test func monochromeTonesTheWholePicture() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.6, green: 0.3, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.monochromeTint = .sepia
        settings.monochromeAmount = 100
        let result = try apply(.monochrome, to: source, settings: settings)
        #expect(result[0] > result[2], "the sepia tint warms the gray: \(result[0]) vs \(result[2])")
        let spread = Int(result[0]) - Int(result[2])
        #expect(result[1] < result[0] && result[1] > result[2])
        #expect(spread > 2)
    }

    @Test func lensFlareLightsTheChosenSpot() throws {
        let context = try BrushRaster.context(width: 32, height: 32, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.lensFlarePosition = .center
        settings.lensFlareBrightness = 150
        settings.lensFlareSize = 50
        let result = try apply(.lensFlare, to: source, settings: settings)
        let center = (16 * 32 + 16) * 4
        #expect(result[center] > 90, "the light brightens the center: \(result[center])")
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == 255 })
    }

    @Test func solarizeInvertsOnlyTheBrightTones() throws {
        let context = try BrushRaster.context(width: 16, height: 8, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0.7, green: 0.7, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 8, y: 0, width: 8, height: 8))
        let source = try #require(context.makeImage())
        let result = try apply(.solarize, to: source, settings: FilterSettings())
        #expect(abs(Int(result[4]) - 26) <= 3, "the dark half stays: \(result[4])")
        #expect(result[(8 + 4) * 4] < 100, "the bright half inverts: \(result[(8 + 4) * 4])")
    }

    @Test func offsetWrapsWhatLeavesOneSideOntoTheOther() throws {
        let context = try BrushRaster.context(width: 16, height: 8, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 8, y: 0, width: 8, height: 8))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.offsetX = 8
        let result = try apply(.offset, to: source, settings: settings)
        let left = (4 * 16 + 4) * 4, right = (4 * 16 + 12) * 4
        #expect(result[left + 2] >= 250, "the blue half wraps to the left: \(result[left]), \(result[left + 2])")
        #expect(result[right] >= 250, "the red half wraps to the right: \(result[right]), \(result[right + 2])")
    }

    @Test func selectiveColorTakesCyanOutOfTheNeutrals() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.selectiveNeutrals.cyan = 100
        let result = try apply(.selectiveColor, to: source, settings: settings)
        #expect(result[0] < 20, "the red goes down: \(result[0])")
        #expect(abs(Int(result[1]) - 128) <= 4 && abs(Int(result[2]) - 128) <= 4)
    }

    @Test func replaceColorMovesRedToGreen() throws {
        let context = try BrushRaster.context(width: 16, height: 16, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.replaceTargetHue = 0
        settings.replaceTolerance = 60
        settings.replaceHue = 120
        let result = try apply(.replaceColor, to: source, settings: settings)
        #expect(result[0] < 10 && result[1] > 240, "red became green: \(result[0]), \(result[1])")
    }

    @Test func tiltShiftKeepsTheBandSharpAndBlursAwayFromIt() throws {
        let context = try BrushRaster.context(width: 40, height: 40, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 40))
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 40))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.tiltShiftRadius = 12
        settings.tiltShiftBand = 10
        let result = try apply(.tiltShiftBlur, to: source, settings: settings)
        let top = (0 * 40 + 20) * 4, middle = (20 * 40 + 20) * 4
        #expect(result[top] > 10, "the far edge blurs across the seam: \(result[top]), \(result[top + 1])")
        #expect(result[middle] < 40 && result[middle + 1] > 200, "the band stays sharp: \(result[middle]), \(result[middle + 1])")
    }

    @Test func irisBlurKeepsTheCenterSharp() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        for y in stride(from: 0, to: 41, by: 4) {
            for x in stride(from: 0, to: 41, by: 4) {
                let red = (x / 4 + y / 4).isMultiple(of: 2)
                context.setFillColor(CGColor(srgbRed: red ? 1 : 0, green: red ? 0 : 1, blue: 0, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.irisBlurRadius = 8
        settings.irisRadius = 6
        settings.irisFeather = 100
        let result = try apply(.irisBlur, to: source, settings: settings)
        let center = (20 * 41 + 20) * 4, corner = (2 * 41 + 2) * 4
        let centerPure = result[center] > 200 && result[center + 1] < 50
            || result[center + 1] > 200 && result[center] < 50
        #expect(centerPure, "the center stays sharp: \(result[center]), \(result[center + 1])")
        #expect(result[corner] > 30 && result[corner + 1] > 30, "the corner blurs: \(result[corner]), \(result[corner + 1])")
    }

    @Test func fieldBlurKeepsItsPointSharpAndBlursAwayFromIt() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        for y in stride(from: 0, to: 41, by: 4) {
            for x in stride(from: 0, to: 41, by: 4) {
                let red = (x / 4 + y / 4).isMultiple(of: 2)
                context.setFillColor(CGColor(srgbRed: red ? 1 : 0, green: red ? 0 : 1, blue: 0, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.fieldBlurRadius = 8
        settings.fieldReach = 100
        let result = try apply(.fieldBlur, to: source, settings: settings)
        let center = (20 * 41 + 20) * 4, corner = (2 * 41 + 2) * 4
        let centerPure = result[center] > 200 && result[center + 1] < 50
            || result[center + 1] > 200 && result[center] < 50
        #expect(centerPure, "the point stays sharp: \(result[center]), \(result[center + 1])")
        #expect(result[corner] > 30 && result[corner + 1] > 30, "the corner blurs: \(result[corner]), \(result[corner + 1])")
    }

    @Test func spinBlurSweepsTheOuterPictureAroundItsCenter() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 41, height: 41))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 30, y: 16, width: 8, height: 8))
        let source = try #require(context.makeImage())
        let original = try pixels(source)
        var settings = FilterSettings()
        settings.spinAmount = 30
        let result = try apply(.spinBlur, to: source, settings: settings)
        // A point the red square sweeps through as the picture turns: blue before, red mixed in after.
        let swept = (24 * 41 + 33) * 4, center = (20 * 41 + 20) * 4
        #expect(original[swept] < 10)
        #expect(result[swept] > 30, "the turn carries red into the arc: \(result[swept])")
        #expect(result[center] < 10, "the center hardly turns: \(result[center])")
    }

    @Test func pathBlurStretchesAlongItsAngle() throws {
        let context = try BrushRaster.context(width: 41, height: 41, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 41))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 20, y: 0, width: 21, height: 41))
        let source = try #require(context.makeImage())
        var across = FilterSettings()
        across.pathDistance = 12
        across.pathAngle = 0
        let streaked = try apply(.pathBlur, to: source, settings: across)
        let seam = (20 * 41 + 20) * 4
        #expect(streaked[seam] > 20 && streaked[seam + 2] > 20, "the seam blends across: \(streaked[seam]), \(streaked[seam + 2])")
        // Turned to run along the bands, the path moves no color: rows keep their red or blue.
        var along = across
        along.pathAngle = 90
        let kept = try apply(.pathBlur, to: source, settings: along)
        let left = (10 * 41 + 8) * 4, right = (30 * 41 + 32) * 4
        #expect(kept[left] > 200 && kept[left + 2] < 50, "the red band stays red: \(kept[left]), \(kept[left + 2])")
        #expect(kept[right + 2] > 200 && kept[right] < 50, "the blue band stays blue: \(kept[right]), \(kept[right + 2])")
    }

    @Test func cloudsAreDeterministicAndOpaque() throws {
        let context = try BrushRaster.context(width: 24, height: 24, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        let source = try #require(context.makeImage())
        var settings = FilterSettings()
        settings.cloudsScale = 12
        settings.cloudsDetail = 60
        settings.cloudsSeed = 7
        let first = try apply(.clouds, to: source, settings: settings)
        let second = try apply(.clouds, to: source, settings: settings)
        #expect(first == second, "the same seed makes the same clouds")
        let alphas = stride(from: 3, to: first.count, by: 4).map { first[$0] }
        #expect(alphas.allSatisfy { $0 == 255 }, "clouds are opaque, lowest \(alphas.min() ?? 0)")
        #expect(Set(stride(from: 0, to: first.count, by: 4).map { first[$0] }).count > 4, "the clouds have shape")
    }

    @Test func eachFilterCommitsAsOneUndoStepAndKeepsLayerEffects() async throws {
        for kind in [FilterKind.vignette, .bloomGlow, .tonalContrast] {
            let session = EditorSession()
            session.createDocument(width: 48, height: 48)
            let context = try BrushRaster.context(width: 24, height: 24, mask: false)
            context.setFillColor(CGColor(srgbRed: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            context.fill(CGRect(x: 3, y: 3, width: 18, height: 18))
            let image = try #require(context.makeImage())
            session.insert(ImportedImage(image: image, thumbnail: image, name: "Sample"))
            let effects = LayerEffects(stroke: StrokeEffect(size: 3))
            let index = try #require(session.document?.layers.firstIndex(where: { $0.id == session.activeLayerID }))
            session.document?.layers[index].effects = effects
            session.beginFilter(kind)
            #expect(session.filterEdit?.kind == kind)
            let undoCount = session.history.undoCount
            await session.commitFilter()
            #expect(session.filterEdit == nil)
            #expect(session.history.undoCount == undoCount + 1)
            #expect(session.activeLayer?.effects == effects)
        }
    }
}

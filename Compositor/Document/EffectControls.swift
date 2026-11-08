import CoreGraphics
import Foundation

/// A layer effect's rows, as the Mac's effect panel has them: each row's caption, its slider's range, the range its
/// exact field can reach (Distance reaches past its slider), its unit, and how the field shows the value. The Mac's
/// panel and the iOS app's editor both read this table.
nonisolated enum EffectControls {
    struct Row {
        let caption: String
        let slider: ClosedRange<Double>
        let field: ClosedRange<Double>
        let unit: String
        /// What the field shows for a value: Opacity shows 0 to 1 as 0 to 100.
        var scale: Double = 1
        let get: (LayerEffects) -> Double?
        let set: (inout LayerEffects, Double) -> Void
    }

    /// Opacity, which the effects keep from 0 to 1 and show as a percentage.
    static func opacity<Effect>(_ effect: WritableKeyPath<LayerEffects, Effect?>,
                                _ value: WritableKeyPath<Effect, Double>) -> Row {
        Row(caption: "Opacity", slider: 0...1, field: 0...1, unit: "%", scale: 100,
            get: { $0[keyPath: effect]?[keyPath: value] },
            set: { $0[keyPath: effect]?[keyPath: value] = $1 })
    }

    static func row<Effect>(_ caption: String, _ effect: WritableKeyPath<LayerEffects, Effect?>,
                            _ value: WritableKeyPath<Effect, CGFloat>, slider: ClosedRange<Double>,
                            field: ClosedRange<Double>? = nil, unit: String) -> Row {
        Row(caption: caption, slider: slider, field: field ?? slider, unit: unit,
            get: { $0[keyPath: effect].map { Double($0[keyPath: value]) } },
            set: { $0[keyPath: effect]?[keyPath: value] = CGFloat($1) })
    }

    /// A choice of named options, as Pattern Overlay's pattern, shown above the effect's rows.
    struct Choice {
        let caption: String
        let titles: [String]
        let chosen: (LayerEffects) -> Int
        let choose: (inout LayerEffects, Int) -> Void
    }

    static let choices: [LayerEffectKind: Choice] = [
        .patternOverlay: Choice(caption: "Pattern", titles: PatternPreset.allCases.map(\.displayName),
                                chosen: { effects in
                                    PatternPreset.allCases.firstIndex(of: effects.patternOverlay?.pattern ?? .dots) ?? 0
                                },
                                choose: { effects, index in
                                    guard PatternPreset.allCases.indices.contains(index) else { return }
                                    effects.patternOverlay?.pattern = PatternPreset.allCases[index]
                                }),
    ]

    static let all: [LayerEffectKind: [Row]] = [
        .stroke: [row("Size", \.stroke, \.size, slider: 0...20, field: 0...Double(StrokeEffect.maxSize), unit: "px"),
                  opacity(\.stroke, \.opacity)],
        .shadow: [opacity(\.shadow, \.opacity), row("Angle", \.shadow, \.angle, slider: -180...180, unit: "°"),
                  row("Distance", \.shadow, \.distance, slider: 0...100, field: 0...5000, unit: "px"),
                  row("Blur", \.shadow, \.blur, slider: 0...100, field: 0...500, unit: "px")],
        .colorOverlay: [opacity(\.colorOverlay, \.opacity)],
        .innerShadow: [opacity(\.innerShadow, \.opacity), row("Angle", \.innerShadow, \.angle, slider: -180...180, unit: "°"),
                       row("Distance", \.innerShadow, \.distance, slider: 0...50, field: 0...5000, unit: "px"),
                       row("Blur", \.innerShadow, \.blur, slider: 0...100, field: 0...500, unit: "px")],
        .outerGlow: [row("Size", \.outerGlow, \.size, slider: 0...100, field: 0...500, unit: "px"),
                     opacity(\.outerGlow, \.opacity)],
        .innerGlow: [row("Size", \.innerGlow, \.size, slider: 0...100, field: 0...500, unit: "px"),
                     opacity(\.innerGlow, \.opacity)],
        .gradientOverlay: [opacity(\.gradientOverlay, \.opacity),
                           row("Angle", \.gradientOverlay, \.angle, slider: -180...180, unit: "°")],
        .patternOverlay: [opacity(\.patternOverlay, \.opacity),
                          row("Angle", \.patternOverlay, \.angle, slider: -180...180, unit: "°"),
                          row("Scale", \.patternOverlay, \.scale, slider: 10...400, field: 1...1000, unit: "%")],
        .satin: [opacity(\.satin, \.opacity), row("Angle", \.satin, \.angle, slider: -180...180, unit: "°"),
                 row("Distance", \.satin, \.distance, slider: 0...50, field: 0...5000, unit: "px"),
                 row("Size", \.satin, \.size, slider: 0...100, field: 0...500, unit: "px")],
        .bevel: [opacity(\.bevel, \.opacity), row("Angle", \.bevel, \.angle, slider: -180...180, unit: "°"),
                 row("Depth", \.bevel, \.depth, slider: 0...50, field: 0...5000, unit: "px"),
                 row("Size", \.bevel, \.size, slider: 0...100, field: 0...500, unit: "px")],
    ]
}

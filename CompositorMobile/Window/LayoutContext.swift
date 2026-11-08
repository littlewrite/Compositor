import UIKit

/// The room a window gives the editor, measured rather than inferred: the same rules serve an iPhone, an iPad, a
/// Split View column and a Stage Manager window, so nothing here reads the device or its orientation.
///
/// Width picks the skeleton and height can overrule it. The thresholds are derived, not written down: the inspector
/// sits beside the canvas only while the canvas keeps `minimumCanvas`, and a window shorter than
/// `minimumStackedHeight` has no room to stack bars under the canvas.
struct LayoutContext: Equatable {
    /// The skeleton the window's measurements call for.
    enum Shell: Equatable {
        /// The narrowest windows: the canvas keeps the whole width and panels come over it.
        case canvasFirst
        /// Room for the tool rail, with the inspector floating over the canvas while it's shown.
        case rail
        /// Room for the rail and an inspector beside a canvas that keeps its minimum.
        case studio
    }

    /// The narrowest the canvas may become before the inspector gives up its place beside it.
    static let minimumCanvas: CGFloat = 480
    /// `ToolRailView`'s width and the hairline after it.
    static let railWidth: CGFloat = 61
    /// `LayersPanelView`'s width and the hairline before it.
    static let inspectorWidth: CGFloat = 253
    /// Below this height, bars stacked under the canvas leave too little of it.
    static let minimumStackedHeight: CGFloat = 520
    /// The narrowest window that still has room for the rail.
    static let minimumRailWidth: CGFloat = 600

    let width: CGFloat
    let height: CGFloat

    var shell: Shell {
        // A short window gives up its stacked bars before it gives up the rail: 844×390 is wide but only 390 tall.
        if height < Self.minimumStackedHeight { return .rail }
        if width < Self.minimumRailWidth { return .canvasFirst }
        // 61 + 253 + 480 = 794: where the inspector beside the canvas stops leaving it room.
        if width - Self.railWidth - Self.inspectorWidth >= Self.minimumCanvas { return .studio }
        return .rail
    }

    /// Whether the inspector has a place of its own beside the canvas, rather than floating over it.
    var pinsInspector: Bool { shell == .studio }

    /// Whether a panel opened over the canvas covers it, as a sheet does, rather than sitting beside it.
    var presentsOverCanvas: Bool { !pinsInspector }
}

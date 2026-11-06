import CoreGraphics

enum ShellKind {
    case canvasFirst
    case rail
    case studio
}

/// Everything the shell needs to know about the space it was handed. Nothing here asks what
/// device this is: Split View, Stage Manager, a fold, and a phone are all just sizes.
struct LayoutContext: Equatable {
    var size: CGSize

    static let compactWidth: CGFloat = 600
    static let studioWidth: CGFloat = 860
    static let shortHeight: CGFloat = 520
    static let canvasFloor: CGFloat = 480
    static let railWidth: CGFloat = 58
    static let inspectorWidth: CGFloat = 320

    var isShort: Bool { size.height < Self.shortHeight }

    var shell: ShellKind {
        if isShort { return .rail }
        if size.width < Self.compactWidth { return .canvasFirst }
        if size.width < Self.studioWidth { return .rail }
        return .studio
    }

    /// The studio layout pins the inspector only while the canvas keeps its floor.
    var pinsInspector: Bool {
        shell == .studio
            && size.width - Self.railWidth - Self.inspectorWidth >= Self.canvasFloor
    }

    var overlayInspectorWidth: CGFloat {
        min(max(size.width * 0.38, 280), 360)
    }

    var usesCompactChrome: Bool { size.width < 700 || isShort }
}

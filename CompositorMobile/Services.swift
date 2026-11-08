import Foundation

/// What the app makes once and hands to each window: the recent projects every window's menu shows, and the GPU canvas
/// renderer a tab uses as it opens. Tests pass their own, so nothing a window does reaches for a process-wide object.
@MainActor struct MobileServices {
    var recents = MobileRecentProjects()
    var renderer: GPUCanvasRenderer? = .shared
    /// The commands the menu bar holds, which Search Commands finds.
    var commands = CommandRegistry()
    /// Who draws on the canvas: Apple Pencil alone, or fingers too.
    var drawingInput = DrawingInput(defaults: .standard)

    static let shared = MobileServices()
}

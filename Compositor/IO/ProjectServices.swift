#if os(macOS)
import Foundation

/// The file work a window's project does: reading and writing packages, exporting, resizing, and the recent files its
/// menus show. The app makes this once and hands it to each workspace, so a controller reaches no process-wide object.
@MainActor struct ProjectServices {
    var exporter = ImageExporter.shared
    var store = ProjectStore.shared
    var imageResizer = ImageResizer.shared
    var canvasResizer = CanvasResizer.shared
    var recents = RecentProjects.shared

    static let shared = ProjectServices()
}
#endif

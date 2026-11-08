import Foundation
import Testing
import UIKit
@testable import Compositor

/// A window too narrow for the Layers panel beside the canvas, as an iPhone's and a Split View column's are: the panel
/// comes over the canvas from a toolbar button, where a window with room keeps it beside them.
@MainActor @Suite(.serialized, .timeLimit(.minutes(1))) struct MobileCompactLayoutTests {
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        view.subviews.flatMap { subview in ((subview as? T).map { [$0] } ?? []) + views(type, in: subview) }
    }

    private func eventually(_ condition: () -> Bool) async throws {
        try await TestWait.until(2, condition)
    }

    /// The editor laid out at `width` × `height`: the layout follows the view's bounds, so no window is needed.
    private func editor(width: CGFloat, height: CGFloat) -> EditorWindowController {
        let controller = EditorWindowController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        controller.view.layoutIfNeeded()
        return controller
    }

    /// The editor in a window `width` × `height`, for the tests that press a button and need what it opens presented
    /// over it: only a window presents.
    private func windowEditor(width: CGFloat, height: CGFloat) async throws -> (window: UIWindow, controller: EditorWindowController) {
        let controller = EditorWindowController()
        let window = try await TestHostWindow.show(controller, size: CGSize(width: width, height: height))
        return (window, controller)
    }

    private func layersItem(of controller: EditorWindowController) throws -> UIBarButtonItem {
        try #require(controller.navigationItem.leadingItemGroups.flatMap(\.barButtonItems)
            .first { $0.accessibilityLabel == "Layers" })
    }

    private func press(_ item: UIBarButtonItem) throws {
        UIApplication.shared.sendAction(try #require(item.action), to: item.target, from: item, for: nil)
    }

    @Test func aNarrowWindowBringsTheLayersPanelOverTheCanvas() async throws {
        let controller = editor(width: 390, height: 844)
        let panel = try #require(views(LayersPanelView.self, in: controller.view).first)
        try await eventually { panel.transform.tx > 0 }
        #expect(panel.transform.tx > 0, "put away at the window's edge")

        let item = try layersItem(of: controller)
        #expect(!item.isHidden, "the toolbar offers it")
        try press(item)
        try await eventually { panel.transform == .identity }
        #expect(panel.transform == .identity, "out over the canvas")

        try press(item)
        try await eventually { panel.transform.tx > 0 }
        #expect(panel.transform.tx > 0, "put away again")
    }

    /// The toolbar's way into the menus on a touch screen: the same commands the menu bar holds, by name.
    /// A window with no room for the rail gives its tools to the mode bar, and the canvas the whole width; one with room
    /// keeps the rail and gives the bar no height.
    @Test func aNarrowWindowSwapsTheRailForTheModeBar() async throws {
        let controller = editor(width: 390, height: 844)
        let rail = try #require(views(ToolRailView.self, in: controller.view).first)
        let bar = try #require(views(ModeBarView.self, in: controller.view).first)
        #expect(rail.isHidden, "the rail's tools move to the bar")
        #expect(!bar.isHidden)
        let canvas = try #require(views(MobileCanvasView.self, in: controller.view).first)
        let left = canvas.convert(canvas.bounds, to: controller.view).minX
        #expect(left <= controller.view.safeAreaInsets.left + 1, "the canvas keeps the width the rail had")
    }

    @Test func aWideWindowKeepsTheRailAndFoldsTheBarAway() async throws {
        let controller = editor(width: 1194, height: 834)
        let rail = try #require(views(ToolRailView.self, in: controller.view).first)
        let bar = try #require(views(ModeBarView.self, in: controller.view).first)
        #expect(!rail.isHidden)
        #expect(bar.isHidden)
    }

    @Test func theToolModeOpensTheGrid() async throws {
        let (window, controller) = try await windowEditor(width: 390, height: 844)
        defer { window.isHidden = true }
        let bar = try #require(views(ModeBarView.self, in: controller.view).first)
        let tools = try #require(views(UIButton.self, in: bar).first { $0.accessibilityLabel == "Tools" })
        #expect(!bar.isHidden)
        tools.sendActions(for: .primaryActionTriggered)
        try await eventually { controller.presentedViewController != nil }
        let navigation = try #require(controller.presentedViewController as? UINavigationController)
        #expect(navigation.viewControllers.first is ToolGridController)
        navigation.dismiss(animated: false)
    }

    @Test func theAdjustModeListsTheAdjustments() async throws {
        let (window, controller) = try await windowEditor(width: 390, height: 844)
        defer { window.isHidden = true }
        let bar = try #require(views(ModeBarView.self, in: controller.view).first)
        let adjust = try #require(views(UIButton.self, in: bar).first { $0.accessibilityLabel == "Adjust" })
        adjust.sendActions(for: .primaryActionTriggered)
        try await eventually { controller.presentedViewController != nil }
        let navigation = try #require(controller.presentedViewController as? UINavigationController)
        #expect(navigation.viewControllers.first is ListPickerController)
        navigation.dismiss(animated: false)
    }

    @Test func theToolbarOpensTheCommands() async throws {
        let (window, controller) = try await windowEditor(width: 390, height: 844)
        defer { window.isHidden = true }
        let item = try #require((controller.navigationItem.leadingItemGroups + controller.navigationItem.trailingItemGroups)
            .flatMap(\.barButtonItems).first { $0.accessibilityLabel == "Commands" })
        #expect(!item.isHidden, "the toolbar offers it")
        try press(item)
        try await eventually { controller.presentedViewController is UINavigationController }
        let navigation = try #require(controller.presentedViewController as? UINavigationController)
        #expect(navigation.viewControllers.first is CommandPaletteController)
    }

    /// What the window shows over the canvas stays inside it, even as narrow as a Split View column: a dialog, the Tools
    /// grid and an adjustment's editor, which is a sheet here rather than a popover pointing at a panel that isn't beside
    /// the canvas.
    @Test func whatTheWindowShowsStaysInsideIt() async throws {
        let (window, controller) = try await windowEditor(width: 390, height: 844)
        defer { window.isHidden = true }
        func inside(_ shown: UIViewController, _ label: String) async throws {
            // A presentation gets its frame as it settles, a moment after it's asked for.
            try await eventually {
                shown.view.layoutIfNeeded()
                return window.bounds.insetBy(dx: -1, dy: -1).contains(shown.view.convert(shown.view.bounds, to: window))
            }
            shown.view.layoutIfNeeded()
            let frame = shown.view.convert(shown.view.bounds, to: window)
            #expect(window.bounds.insetBy(dx: -1, dy: -1).contains(frame), "\(label): \(frame) in \(window.bounds)")
        }

        let bar = try #require(views(ModeBarView.self, in: controller.view).first)
        let tools = try #require(views(UIButton.self, in: bar).first { $0.accessibilityLabel == "Tools" })
        tools.sendActions(for: .primaryActionTriggered)
        try await eventually { controller.presentedViewController != nil }
        let grid = try #require(controller.presentedViewController)
        try await inside(grid, "Tools")
        grid.dismiss(animated: false)
        try await eventually { controller.presentedViewController == nil }

        let session = try #require(controller.activeTab?.session)
        session.createNewProject(width: 200, height: 100)
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Gray"))
        session.beginLevels()
        try await eventually { controller.presentedViewController is LevelsEditorController }
        let levels = try #require(controller.presentedViewController)
        #expect(levels.modalPresentationStyle == .pageSheet, "a sheet where a popover has no panel to point at")
        try await inside(levels, "Levels")
        session.cancelLevels()
    }

    @Test func aWideWindowKeepsTheLayersPanelBesideTheCanvas() async throws {
        let controller = editor(width: 1194, height: 834)
        let panel = try #require(views(LayersPanelView.self, in: controller.view).first)
        #expect(panel.transform == .identity)
        let item = try layersItem(of: controller)
        #expect(item.isHidden, "nothing to bring out")
        let canvas = try #require(views(MobileCanvasView.self, in: controller.view).first)
        #expect(panel.convert(panel.bounds, to: controller.view).maxX <= controller.view.bounds.maxX + 1)
        #expect(canvas.convert(canvas.bounds, to: controller.view).maxX <= panel.convert(panel.bounds, to: controller.view).minX + 1)
    }
}

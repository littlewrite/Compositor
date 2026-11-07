import Foundation
import Testing
import UIKit
@testable import Compositor

/// A window too narrow for the Layers panel beside the canvas, as an iPhone's and a Split View column's are: the panel
/// comes over the canvas from a toolbar button, where a window with room keeps it beside them.
@MainActor @Suite(.serialized) struct PadCompactLayoutTests {
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        view.subviews.flatMap { subview in ((subview as? T).map { [$0] } ?? []) + views(type, in: subview) }
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(20)) }
    }

    private func window(width: CGFloat, height: CGFloat) async throws -> (UIWindow, EditorWindowController) {
        let scene = try #require(UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let controller = EditorWindowController()
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        controller.view.layoutIfNeeded()
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
        let (window, controller) = try await window(width: 390, height: 844)
        defer { window.isHidden = true }
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

    @Test func aWideWindowKeepsTheLayersPanelBesideTheCanvas() async throws {
        let (window, controller) = try await window(width: 1194, height: 834)
        defer { window.isHidden = true }
        let panel = try #require(views(LayersPanelView.self, in: controller.view).first)
        #expect(panel.transform == .identity)
        let item = try layersItem(of: controller)
        #expect(item.isHidden, "nothing to bring out")
        let canvas = try #require(views(PadCanvasView.self, in: controller.view).first)
        #expect(panel.convert(panel.bounds, to: controller.view).maxX <= controller.view.bounds.maxX + 1)
        #expect(canvas.convert(canvas.bounds, to: controller.view).maxX <= panel.convert(panel.bounds, to: controller.view).minX + 1)
    }
}

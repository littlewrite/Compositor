import CoreGraphics
import Testing
import UIKit
@testable import Compositor

/// View › Navigator on iPad: the Mac's minimap in the canvas's corner, shown from 300% zoom when turned on.
@MainActor @Suite(.serialized) struct MobileNavigatorTests {
    private func window() throws -> (EditorWindowController, EditorSession) {
        let window = EditorWindowController()
        window.loadViewIfNeeded()
        let session = try #require(window.activeTab?.session)
        session.createNewProject(width: 200, height: 100)
        return (window, session)
    }

    /// The navigator shows once turned on and the canvas is at 300% or more, and not below it.
    @Test func showsFrom300PercentWhenTurnedOn() throws {
        let (window, session) = try window()
        let canvas = try #require(window.activeTab?.canvas)
        let previous = UserDefaults.standard.bool(forKey: NavigatorView.visibleKey)
        defer { UserDefaults.standard.set(previous, forKey: NavigatorView.visibleKey) }
        UserDefaults.standard.set(false, forKey: NavigatorView.visibleKey)

        session.zoom(to: NavigatorView.zoomShown)
        canvas.navigator.updatePropertiesIfNeeded()
        #expect(canvas.navigator.isHidden)

        window.toggleNavigator(nil)
        canvas.navigator.updatePropertiesIfNeeded()
        #expect(!canvas.navigator.isHidden)
        #expect(canvas.navigator.desiredSize.width > 0)

        session.zoom(to: NavigatorView.zoomShown / 2)
        canvas.navigator.updatePropertiesIfNeeded()
        #expect(canvas.navigator.isHidden)
    }

    /// Its menu command checks itself, as the Mac's does.
    @Test func theMenuCommandChecksItself() throws {
        let (controller, _) = try window()
        let previous = UserDefaults.standard.bool(forKey: NavigatorView.visibleKey)
        defer { UserDefaults.standard.set(previous, forKey: NavigatorView.visibleKey) }
        let command = UICommand(title: "Navigator (300% and above)", action: #selector(EditorWindowController.toggleNavigator(_:)))

        UserDefaults.standard.set(false, forKey: NavigatorView.visibleKey)
        controller.validate(command)
        #expect(command.state == .off)
        controller.toggleNavigator(nil)
        controller.validate(command)
        #expect(command.state == .on)
    }
}

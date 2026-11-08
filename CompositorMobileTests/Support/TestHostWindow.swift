import Testing
import UIKit
@testable import Compositor

/// One test's window at a time. UIKit runs a scene's presentations, key status and first responder through one
/// transition coordinator, and two windows alive at once take them from each other: a dialog's answer goes nowhere,
/// a dismissal never finishes. A test keeps the window for as long as it is up and lets the next have its turn when
/// it goes, which happens within the test that showed it. Headless tests never wait.
@MainActor enum UITestGate {
    private final class Holder { weak var window: TestWindow? }
    private static let holder = Holder()

    /// Waits for the window in the way to go. A window a test lets go of ends the turn with it, and one a test throws
    /// before it can hide leaves the turn after a while, so one mishap doesn't hang every window test after it.
    static func waitForTurn() async throws {
        let start = ContinuousClock.now
        while let held = holder.window, !held.isHidden {
            if start.duration(to: .now) > .seconds(30) { holder.window = nil; break }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    static func take(_ window: TestWindow) { holder.window = window }

    static func release(_ window: TestWindow) {
        if holder.window === window { holder.window = nil }
    }
}

/// A test's window, which gives the next test its turn once it's put away.
final class TestWindow: UIWindow {
    private var gaveTurn = false

    override var isHidden: Bool {
        didSet {
            guard isHidden, !gaveTurn else { return }
            gaveTurn = true
            // What's over the window goes with it, rather than animating away in the scene every window shares.
            rootViewController?.dismiss(animated: false)
            UITestGate.release(self)
        }
    }
}

/// The window the UI tests drive. UIKit presents, takes the keyboard and draws pixels only in a window, so the suites
/// that check those make theirs here: laid out, and given the turn UIKit needs before anything opens over it.
@MainActor enum TestHostWindow {
    /// A window on the app's screen, `size`, showing `controller` — in a navigation controller whose bar is the
    /// window's toolbar unless `toolbar` is false — in `style` when one is given. Only after the test before it has
    /// put its window away.
    static func show(_ controller: UIViewController, size: CGSize = CGSize(width: 1194, height: 834),
                     toolbar: Bool = true, style: UIUserInterfaceStyle? = nil) async throws -> UIWindow {
        try await UITestGate.waitForTurn()
        let scene = try #require(UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first)
        // A test host launches in the background: the system's pickers, menus and keyboard need its scene in front, as
        // the app's window is when someone uses it.
        if scene.activationState != .foregroundActive {
            UIApplication.shared.requestSceneSessionActivation(scene.session, userActivity: nil, options: nil)
            for _ in 0..<50 where scene.activationState != .foregroundActive {
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        let window = TestWindow(windowScene: scene)
        UITestGate.take(window)
        window.frame = CGRect(origin: .zero, size: size)
        if let style { window.overrideUserInterfaceStyle = style }
        window.rootViewController = toolbar ? UINavigationController(rootViewController: controller) : controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        return window
    }
}

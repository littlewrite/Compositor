import Observation
import UIKit

// iPadOS 26 gives every view and controller an update-properties pass, run before the next frame (see
// `setNeedsUpdateProperties`): UIKit runs `updateProperties` inside observation tracking and runs it again whenever an
// observable property it read changes. Xcode 16.4's SDK has no such pass, so on it these base classes stand in for it,
// running the same way. The subclasses keep one `override func updateProperties()`, which is an override of `UIView`'s
// on the newer SDK and of these on the older one.
#if swift(<6.2)
extension UIView {
    func setNeedsUpdateProperties() { (self as? PadView)?.requestUpdateProperties() }
    func updatePropertiesIfNeeded() { (self as? PadUpdating)?.updateTrackedProperties() }
}

extension UIViewController {
    func setNeedsUpdateProperties() { (self as? PadUpdating)?.requestUpdateProperties() }
    func updatePropertiesIfNeeded() { (self as? PadUpdating)?.updateTrackedProperties() }
}

/// The update pass on the older SDK: `updateProperties` once, then again whenever an observable property it read
/// changes, a turn later, as UIKit's pass does.
protocol PadUpdating: AnyObject {
    var updateScheduled: Bool { get set }
    func updateProperties()
}

extension PadUpdating {
    func requestUpdateProperties() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in self?.updateTrackedProperties() }
    }

    func updateTrackedProperties() {
        updateScheduled = false
        withObservationTracking {
            updateProperties()
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.requestUpdateProperties() }
        }
    }
}

class PadView: UIView, PadUpdating {
    var updateScheduled = false
    private var watchesAppearance = false
    func updateProperties() {}

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Colors the update pass sets on layers don't resolve a dynamic color again by themselves.
        if !watchesAppearance {
            watchesAppearance = true
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PadView, _) in
                view.requestUpdateProperties()
                view.setNeedsDisplay()
            }
        }
        requestUpdateProperties()
    }
}

class PadViewController: UIViewController, PadUpdating {
    var updateScheduled = false
    private var hasUpdated = false
    func updateProperties() {}

    /// The pass reaches a controller as its view is first laid out and as it appears, as UIKit's does.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasUpdated else { return }
        hasUpdated = true
        updateTrackedProperties()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTrackedProperties()
    }

    /// What a controller shows gets its pass before it comes up, so it is laid out at the right size and says what it
    /// has to from the first frame.
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        (viewControllerToPresent as? PadUpdating)?.updateTrackedProperties()
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

class PadTableViewController: UITableViewController, PadUpdating {
    var updateScheduled = false
    private var hasUpdated = false
    func updateProperties() {}

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasUpdated else { return }
        hasUpdated = true
        updateTrackedProperties()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTrackedProperties()
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        (viewControllerToPresent as? PadUpdating)?.updateTrackedProperties()
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

extension UIButton.Configuration {
    /// The 26 SDK's glass buttons: a plain bezel, and a tinted one for the main action.
    static func glass() -> UIButton.Configuration { .gray() }
    static func prominentGlass() -> UIButton.Configuration { .filled() }
}

extension UIBarButtonItem.Style {
    /// The 26 SDK's prominent bar button: the older SDK's Done, which shows its title the same way.
    static var prominent: UIBarButtonItem.Style { .done }
}
#else
typealias PadView = UIView
typealias PadViewController = UIViewController
typealias PadTableViewController = UITableViewController
#endif

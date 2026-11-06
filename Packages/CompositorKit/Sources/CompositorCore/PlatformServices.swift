import CoreGraphics
import Foundation

/// What a host can do, asked as data rather than tested with `#if`. The iPad and the Mac each
/// answer for themselves; shared views branch on the answer, never on the operating system.
public struct PlatformCapabilities: Sendable, Equatable {
    /// A mouse or trackpad pointer that hovers before it clicks.
    public var hasHoverPointer: Bool
    /// A hardware keyboard, for shortcuts and modifier keys that can be held down.
    public var hasHardwareKeyboard: Bool
    /// Pressure and tilt from a stylus.
    public var supportsPencilPressure: Bool
    /// The platform draws its own cursor; the editor must not invent one.
    public var showsPointerCursor: Bool

    public init(hasHoverPointer: Bool, hasHardwareKeyboard: Bool,
                supportsPencilPressure: Bool, showsPointerCursor: Bool) {
        self.hasHoverPointer = hasHoverPointer
        self.hasHardwareKeyboard = hasHardwareKeyboard
        self.supportsPencilPressure = supportsPencilPressure
        self.showsPointerCursor = showsPointerCursor
    }
}

/// The modifiers a gesture is being made with. On the Mac these come from the event; on the iPad
/// from on-screen toggles, because a finger cannot hold one down.
public struct ModifierSet: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let command = ModifierSet(rawValue: 1 << 2)
}

public enum CanvasPointerKind: Sendable {
    case touch
    case pencil
    case mouse
}

/// One pointer event, normalized before any tool sees it.
public struct CanvasPointer: Sendable {
    /// In document pixels.
    public var location: CGPoint
    /// 0…1; 1 for a mouse, the stylus's force for a pencil, a nominal 0.5 for a finger.
    public var pressure: CGFloat
    public var kind: CanvasPointerKind
    public var modifiers: ModifierSet

    public init(location: CGPoint, pressure: CGFloat, kind: CanvasPointerKind, modifiers: ModifierSet) {
        self.location = location
        self.pressure = pressure
        self.kind = kind
        self.modifiers = modifiers
    }
}

/// Supplies the modifiers in force. A strategy, so the canvas asks this and not the OS.
@MainActor
public protocol ModifierStrategy: AnyObject {
    var active: ModifierSet { get }
    /// True where modifiers are offered as on-screen toggles (iPad). False where they are held
    /// down on a keyboard (Mac) and drawing chips for them would be noise.
    var offersOnScreenModifiers: Bool { get }
    func toggle(_ modifier: ModifierSet)
    func clear()
}

@MainActor
public protocol HapticsStrategy: AnyObject {
    func selectionChanged()
    func impact()
}

@MainActor
public protocol FileStrategy: AnyObject {
    /// A file the person chose, still on disk so RAW can be developed rather than loaded as bytes.
    func pickImage() async -> URL?
    func save(_ data: Data, suggestedName: String) async -> Bool
}

/// Everything the editor needs from its host. One concrete implementation per entry point:
/// `PadPlatform` answers with UIKit, the Mac's own answers with AppKit, and neither leaks in.
@MainActor
public protocol PlatformServices: AnyObject {
    var capabilities: PlatformCapabilities { get }
    var modifiers: ModifierStrategy { get }
    var haptics: HapticsStrategy { get }
    var files: FileStrategy { get }
}

import UIKit

/// The line along the foot of the window, as on the Mac: the zoom, the canvas's size and color space, and on the
/// right what the tool in hand does, or what the editor is busy with.
final class StatusBarView: MobileView {
    var session: EditorSession? { didSet { if session !== oldValue { setNeedsUpdateProperties() } } }
    /// Whether a finger paints, as `DrawingInput` says; the hints say what draws.
    var fingerPaints = true { didSet { setNeedsUpdateProperties() } }
    /// A project is opening in the tab: it isn't waiting for a canvas.
    var isOpening = false { didSet { if isOpening != oldValue { setNeedsUpdateProperties() } } }
    /// A word on what just changed, said in the hint's place for a moment.
    private(set) var flashed: String?
    private var flashEnd: Task<Void, Never>?

    static let height: CGFloat = 30

    private let zoom = StatusBarView.label()
    private let size = StatusBarView.label()
    private let space = StatusBarView.label()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let hint = StatusBarView.label()

    override init(frame: CGRect) {
        super.init(frame: frame)
        zoom.widthAnchor.constraint(equalToConstant: 62).isActive = true
        hint.textAlignment = .right
        hint.lineBreakMode = .byTruncatingHead
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        spinner.hidesWhenStopped = true
        spinner.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        let leading = UIStackView(arrangedSubviews: [zoom, size, space])
        leading.spacing = 16
        let trailing = UIStackView(arrangedSubviews: [spinner, hint])
        trailing.spacing = 6
        let row = UIStackView(arrangedSubviews: [leading, UIView(), trailing])
        row.spacing = 16
        row.alignment = .center
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.heightAnchor.constraint(equalToConstant: Self.height),
        ])
        leading.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessibilityElements = [zoom, size, space, hint]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateProperties() {
        super.updateProperties()
        guard let session else { return }
        if let document = session.document {
            zoom.text = Double(session.viewport.zoom).formatted(.percent.precision(.fractionLength(0...1)))
            size.text = "\(document.width) × \(document.height) px"
            space.text = "sRGB · Transparent".localized
        } else {
            zoom.text = nil
            size.text = isOpening ? nil : "Ready when you are".localized
            space.text = nil
        }
        for label in [zoom, size, space] { label.isHidden = label.text == nil }
        if session.showsBusy || session.isImporting {
            spinner.startAnimating()
            hint.text = session.showsBusy ? "Working…" : "Importing images…"
        } else {
            spinner.stopAnimating()
            hint.text = session.document == nil ? nil : flashed ?? Self.hint(for: session, fingerPaints: fingerPaints)
        }
        hint.textColor = flashed == nil || session.showsBusy || session.isImporting ? .secondaryLabel : .tintColor
    }

    /// How long a flash stays before the hint comes back.
    static let flashDuration: Duration = .seconds(3)

    /// Says `message` in the hint's place, in the accent color, for `duration`, and to VoiceOver: a mode just switched,
    /// say, and what it switched to.
    func flash(_ message: String, for duration: Duration = flashDuration) {
        flashEnd?.cancel()
        crossfade { self.flashed = message }
        UIAccessibility.post(notification: .announcement, argument: message)
        flashEnd = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.crossfade { self?.flashed = nil }
        }
    }

    private func crossfade(_ change: @escaping () -> Void) {
        UIView.transition(with: hint, duration: 0.25, options: .transitionCrossDissolve) {
            change()
            self.setNeedsUpdateProperties()
            self.updatePropertiesIfNeeded()
        }
    }

    /// What the tool in hand does, as the Mac's status bar says it, for touch.
    static func hint(for session: EditorSession, fingerPaints: Bool) -> String {
        let fingers = (fingerPaints ? "Two fingers move and zoom" : "Fingers move and zoom").localized
        let pencil = (fingerPaints ? "Drag" : "Draw with Apple Pencil").localized
        switch session.tool {
        case .brush:
            let action = (session.brushMode == .erase ? "erase" : "paint").localized
            return String(format: "%@ to %@ · %@".localized, pencil, action, fingers)
        case .spotHealing:
            return String(format: "%@ over blemishes to heal · %@".localized, pencil, fingers)
        case .cloneStamp where session.cloneSource == nil:
            let tap = (fingerPaints ? "Tap" : "Tap with Apple Pencil").localized
            return String(format: "%@ where to copy from · %@".localized, tap, fingers)
        case .cloneStamp:
            return String(format: "%@ to clone · Drag the crosshair, or Option-tap, to copy from elsewhere · %@".localized,
                          pencil, fingers)
        case .blur:
            let action = (session.blurMode == .blur ? "soften" : session.blurMode == .smudge ? "smudge" : "push pixels").localized
            return String(format: "%@ to %@ · %@".localized, pencil, action, fingers)
        case .move:
            // A finger moves layers whether or not it paints.
            let move = (session.transformAutoSelect ? "Drag on a layer to select and move it" : "Drag to move the layer").localized
            let handles = session.showsTransformControls ? " · Handles to resize · Circle to rotate".localized : ""
            return move + handles + " · " + fingers
        case .marquee:
            let shape = (session.marqueeKind == .ellipse ? "an ellipse" : "a rectangle").localized
            return String(format: "Drag %@ · Drag inside to move it · Two fingers move and zoom".localized, shape)
        case .lasso where session.lassoKind == .polygonal:
            return "Tap corners · Tap the first corner or double-tap to close · Two fingers move and zoom".localized
        case .lasso:
            return "Draw around what to select · Drag inside to move it · Two fingers move and zoom".localized
        case .wand:
            let tap = (session.wandMode == .object ? "Tap an object to select it" : "Tap to select similar colors").localized
            return String(format: "%@ · Drag inside to move it · Two fingers move and zoom".localized, tap)
        case .crop:
            return "Drag a frame, or its edges · Drag inside to move it · Two fingers move and zoom".localized
        case .gradient:
            let drag = (fingerPaints ? "Drag out a gradient" : "Drag out a gradient with Apple Pencil").localized
            return String(format: "%@, or move one of its ends · %@".localized, drag, fingers)
        case .shape:
            let shape = (session.shapeKind == .ellipse ? "an ellipse"
                         : session.shapeKind == .line ? "a line" : "a rectangle").localized
            let key = fingerPaints ? "Drag out %@ · %@" : "Drag out %@ with Apple Pencil · %@"
            return String(format: key.localized, shape, fingers)
        case .type where session.textDraft != nil:
            return "Type · Drag the box's edges to wrap the text · Done keeps it, Cancel puts it back".localized
        case .type:
            return "Tap to type · Drag a box for a paragraph · Tap text to edit it · Two fingers move and zoom".localized
        case .eyedropper:
            return "Touch to pick up a color · Two fingers move and zoom".localized
        case .hand:
            return "Drag to pan · Pinch to zoom".localized
        case .zoom:
            return "Tap to zoom in · Drag right or left to zoom smoothly".localized
        case .idle:
            return "No tool selected".localized
        }
    }

    private static func label() -> UILabel {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }
}

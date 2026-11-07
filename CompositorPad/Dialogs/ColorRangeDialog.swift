import Observation
import UIKit

/// Select › Color Range…, as the Mac's panel: the image to pick colors from, the eyedroppers, Fuzziness and Invert, with
/// the selection shown beside them. The selection updates as it's edited and OK keeps it as one undo step; Cancel puts
/// back the selection there was.
final class ColorRangeController: SizeDialogController {
    private let session: EditorSession
    private let dismissDialog: () -> Void

    private let picker = ColorRangePickerView()
    private let preview = UIImageView()
    private let previewBox = UIView()
    private let hint = SizeDialogController.note()
    private let errorLabel = SizeDialogController.note()
    private let fuzziness = SliderField(caption: "Fuzziness", sliderRange: ColorRangeEdit.fuzzinessRange,
                                        fieldRange: ColorRangeEdit.fuzzinessRange, sensitivity: 1, sliderWidth: nil)
    private lazy var invert = OptionControls.checkbox("Invert") { [weak self] on in
        guard let self, let edit = self.session.colorRange else { return }
        edit.invert = on
        self.session.updateColorRange()
    }
    private lazy var droppers = HueSampleMode.allCases.map { mode in
        Self.dropper(mode) { [weak self] in
            guard let self, let edit = self.session.colorRange else { return }
            edit.sampleMode = mode
            self.refresh()
        }
    }

    init(session: EditorSession, dismiss: @escaping () -> Void) {
        self.session = session
        dismissDialog = dismiss
        super.init(title: "Color Range".localized, confirm: "OK".localized)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        picker.accessibilityLabel = "Image to pick colors from".localized
        picker.heightAnchor.constraint(equalToConstant: 260).isActive = true
        picker.onPick = { [weak self] point in self?.pick(at: point) }

        preview.contentMode = .scaleAspectFit
        previewBox.backgroundColor = .black
        previewBox.layer.cornerRadius = 4
        previewBox.layer.masksToBounds = true
        previewBox.addSubview(preview)
        preview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewBox.heightAnchor.constraint(equalToConstant: 120),
            preview.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor),
            preview.topAnchor.constraint(equalTo: previewBox.topAnchor),
            preview.bottomAnchor.constraint(equalTo: previewBox.bottomAnchor),
        ])

        fuzziness.onChange = { [weak self] value in self?.setFuzziness(value) }

        errorLabel.textColor = .systemOrange
        errorLabel.isHidden = true

        let dropperRow = UIStackView(arrangedSubviews: droppers + [UIView()])
        dropperRow.axis = .horizontal
        dropperRow.spacing = 6

        for view in [dropperRow, picker, hint, previewBox, fuzziness, invert, errorLabel] as [UIView] {
            content.addArrangedSubview(view)
        }
        super.viewDidLoad()
        // After the base's viewDidLoad puts the content in the view, where the two have an ancestor to relate.
        picker.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observe()
    }

    /// Redraws as the selection changes, as the Mac's panel does while its colors are picked and matched.
    private func observe() {
        guard view.window != nil else { return }
        withObservationTracking {
            refresh()
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.observe() }
        }
    }

    override func refresh() {
        guard let edit = session.colorRange else { return }
        picker.image = edit.image
        preview.image = edit.preview.map { UIImage(cgImage: $0) }
        previewBox.isHidden = edit.preview == nil
        fuzziness.show(edit.fuzziness)
        invert.isSelected = edit.invert
        errorLabel.text = edit.error
        errorLabel.isHidden = edit.error == nil
        hint.text = edit.hasColors ? "Tap the image to add a color to the selection, or to start over from another."
                                   : "Tap the image to pick the color to select."
        for (mode, button) in zip(HueSampleMode.allCases, droppers) {
            let armed = edit.effectiveMode == mode
            button.configuration?.background.backgroundColor = armed ? UIColor.tintColor.withAlphaComponent(0.25) : .clear
            button.accessibilityTraits = armed ? [.button, .selected] : .button
        }
    }

    /// A tap on the image, in document pixels, picks that color as the eyedropper chosen says.
    func pick(at point: CGPoint) {
        session.sampleColorRange(at: point, shift: false, option: false)
        refresh()
    }

    func setFuzziness(_ value: Double) {
        guard let edit = session.colorRange else { return }
        let clamped = min(ColorRangeEdit.fuzzinessRange.upperBound,
                          max(ColorRangeEdit.fuzzinessRange.lowerBound, value.rounded()))
        guard edit.fuzziness != clamped else { return }
        edit.fuzziness = clamped
        session.updateColorRange()
    }

    override func confirm() {
        session.commitColorRange()
        dismissDialog()
    }
    override func cancel() {
        session.cancelColorRange()
        dismissDialog()
    }

    /// An eyedropper, with Add's and Remove's small badge, as Hue/Saturation's.
    private static func dropper(_ mode: HueSampleMode, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: mode.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16))
        configuration.baseForegroundColor = .label
        configuration.contentInsets = .zero
        configuration.background.cornerRadius = 6
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = mode.rawValue + " color"
        if let badge = mode.badge {
            let mark = UIImageView(image: UIImage(systemName: badge, withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .semibold)))
            mark.tintColor = .label
            button.addSubview(mark)
            mark.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([mark.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 9),
                                         mark.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: 8)])
        }
        NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 34),
                                     button.heightAnchor.constraint(equalToConstant: 32)])
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }
}

/// The image as the dialog shows it to pick colors from: fitted to the room there is, told the document point a tap
/// lands on.
final class ColorRangePickerView: UIControl {
    var image: CGImage? { didSet { setNeedsDisplay() } }
    var onPick: ((CGPoint) -> Void)?

    private var imageRect: CGRect {
        guard let image else { return .zero }
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let scale = min(bounds.width / width, bounds.height / height)
        let size = CGSize(width: width * scale, height: height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let image else { return }
        // Through UIImage so the image's own orientation and the view's flipped coordinates agree.
        UIImage(cgImage: image).draw(in: imageRect)
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard let image else { return }
        let rect = imageRect
        let point = gesture.location(in: self)
        guard rect.contains(point), rect.width > 0, rect.height > 0 else { return }
        onPick?(CGPoint(x: (point.x - rect.minX) / rect.width * CGFloat(image.width),
                        y: (point.y - rect.minY) / rect.height * CGFloat(image.height)))
    }
}

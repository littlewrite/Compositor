import UIKit

/// What an empty tab shows, as the Mac's does: a new canvas's size, typed or picked from the presets, and the other
/// ways in, opening a project or bringing in an image. The projects opened lately are listed under it.
final class NewCanvasView: UIView, UITextFieldDelegate {
    var onCreate: (Int, Int) -> Void = { _, _ in }
    var onOpen: () -> Void = {}
    var onImportPhotos: () -> Void = {}
    var onImportFiles: () -> Void = {}
    var onOpenRecent: (URL) -> Void = { _ in }

    private let width = NewCanvasView.field("1920")
    private let height = NewCanvasView.field("1080")
    private let caption = UILabel()
    private let create = UIButton(configuration: .prominentGlass())
    private let recent = UIStackView()
    private let recentTitle = UILabel()
    private let buttons = UIStackView()
    private let buttonSpacer = UIView()
    private let card = NewCanvasView.card()
    private let sizeRow = UIStackView()
    /// Whether the card last restacked for a narrow width, so a layout pass that changes nothing doesn't restack.
    private var lastStacked: Bool?
    /// Between the fields, as tall as they are, so it sits level with them rather than their labels.
    private let swap = UIButton(configuration: {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "arrow.left.arrow.right")
        configuration.baseForegroundColor = .secondaryLabel
        return configuration
    }())

    override init(frame: CGRect) {
        super.init(frame: frame)

        let title = UILabel()
        title.text = "New canvas".localized
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        var presetsConfiguration = UIButton.Configuration.plain()
        presetsConfiguration.image = UIImage(systemName: "ellipsis")
        presetsConfiguration.baseForegroundColor = .label
        let presets = UIButton(configuration: presetsConfiguration)
        presets.accessibilityLabel = "Preset sizes".localized
        presets.showsMenuAsPrimaryAction = true
        presets.menu = UIMenu(children: CanvasPreset.groups.map { group in
            UIMenu(options: .displayInline, children: group.map { preset in
                UIAction(title: preset.title.localized, subtitle: "\(preset.width) × \(preset.height) px") { [weak self] _ in
                    self?.width.text = String(preset.width)
                    self?.height.text = String(preset.height)
                    self?.validate()
                }
            })
        })
        let header = UIStackView(arrangedSubviews: [title, UIView(), presets])

        swap.accessibilityLabel = "Swap width and height".localized
        swap.setHelp("Swap width and height", hint: nil)
        swap.addAction(UIAction { [weak self] _ in self?.swapSize() }, for: .primaryActionTriggered)
        swap.translatesAutoresizingMaskIntoConstraints = false
        // Not required, as a stack puts a hidden arranged subview away at zero size, and a required size here would
        // leave the two constraints fighting over the card's width.
        let swapWidth = swap.widthAnchor.constraint(equalToConstant: 44)
        let swapHeight = swap.heightAnchor.constraint(equalToConstant: 44)
        swapWidth.priority = .defaultHigh
        swapHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([swapWidth, swapHeight])
        for view in [Self.labeled("Width", width), swap, Self.labeled("Height", height)] { sizeRow.addArrangedSubview(view) }
        sizeRow.spacing = 16
        sizeRow.alignment = .bottom
        sizeRow.distribution = .equalCentering
        for field in [width, height] {
            field.delegate = self
            field.addAction(UIAction { [weak self] _ in self?.validate() }, for: .editingChanged)
        }

        caption.font = .preferredFont(forTextStyle: .callout)
        caption.numberOfLines = 0

        var openConfiguration = UIButton.Configuration.glass()
        openConfiguration.title = "Open project".localized
        let open = UIButton(configuration: openConfiguration)
        open.addAction(UIAction { [weak self] _ in self?.onOpen() }, for: .primaryActionTriggered)
        var importConfiguration = UIButton.Configuration.glass()
        importConfiguration.title = "Import image".localized
        let importButton = UIButton(configuration: importConfiguration)
        // From Photos, or from Files, where Photoshop and RAW files usually are.
        importButton.menu = UIMenu(children: [
            UIAction(title: "From Photos".localized, image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in self?.onImportPhotos() },
            UIAction(title: "From Files".localized, image: UIImage(systemName: "folder")) { [weak self] _ in self?.onImportFiles() },
        ])
        importButton.showsMenuAsPrimaryAction = true
        create.configuration?.title = "Create canvas".localized
        create.addAction(UIAction { [weak self] _ in self?.createCanvas() }, for: .primaryActionTriggered)
        // The ways in, side by side in a card with room for them, stacked down a narrow one.
        buttons.spacing = 10
        for view in [open, importButton, buttonSpacer, create] { buttons.addArrangedSubview(view) }

        recentTitle.text = "Recent".localized
        recentTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        recentTitle.textColor = .secondaryLabel
        recent.axis = .vertical
        recent.spacing = 2

        let content = UIStackView(arrangedSubviews: [header, sizeRow, caption, buttons, recentTitle, recent])
        content.axis = .vertical
        content.spacing = 22
        content.setCustomSpacing(10, after: recentTitle)
        card.addSubview(content)
        addSubview(card)
        for view in [card, content] as [UIView] { view.translatesAutoresizingMaskIntoConstraints = false }
        // As wide as the Mac's card where there's room, and as wide as the tab where there isn't.
        let width = card.widthAnchor.constraint(equalToConstant: 520)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor), card.centerYAnchor.constraint(equalTo: centerYAnchor),
            width,
            card.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),
        ])
        validate()
        // A layer's border color doesn't resolve the appearance again by itself.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: NewCanvasView, _) in
            view.card.layer.borderColor = Palette.separator.cgColor
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A card too narrow for the three buttons in a row stacks them, each as wide as the card, and puts Height under
    /// Width, without the swap between them, so the numbers stay whole.
    override func layoutSubviews() {
        super.layoutSubviews()
        let stacked = bounds.width < 480
        guard bounds.width > 0, stacked != lastStacked else { return }
        lastStacked = stacked
        if (buttons.axis == .vertical) != stacked {
            buttons.axis = stacked ? .vertical : .horizontal
            buttonSpacer.isHidden = stacked
        }
        if (sizeRow.axis == .vertical) != stacked {
            sizeRow.axis = stacked ? .vertical : .horizontal
            sizeRow.alignment = stacked ? .fill : .bottom
            sizeRow.spacing = stacked ? 12 : 16
            swap.isHidden = stacked
        }
    }

    /// The card an empty tab's form sits on, and an opening tab's Loading card too.
    static func card() -> UIView {
        let card = UIView()
        card.backgroundColor = Palette.card
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = Palette.separator.cgColor
        return card
    }

    /// Lists up to five recent projects, or hides the list when there are none.
    func showRecent(_ urls: [URL]) {
        recent.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for url in urls.prefix(5) {
            var configuration = UIButton.Configuration.plain()
            configuration.title = url.deletingPathExtension().lastPathComponent
            configuration.subtitle = url.deletingLastPathComponent().lastPathComponent
            configuration.image = UIImage(systemName: "doc.richtext")
            configuration.imagePadding = 10
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
            let button = UIButton(configuration: configuration)
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in self?.onOpenRecent(url) }, for: .primaryActionTriggered)
            recent.addArrangedSubview(button)
        }
        recentTitle.isHidden = urls.isEmpty
        recent.isHidden = urls.isEmpty
    }

    private func validate() {
        let valid = size != nil
        caption.text = valid ? "Transparent canvas · sRGB".localized
            : String(format: "Enter whole numbers from 1 to %@ pixels.".localized, DocumentLimits.maxSide.formatted())
        caption.textColor = valid ? .secondaryLabel : .systemOrange
        create.isEnabled = valid
    }

    private var size: (Int, Int)? {
        guard let w = CanvasDocument.validDimension(width.text ?? ""), let h = CanvasDocument.validDimension(height.text ?? "") else { return nil }
        return (w, h)
    }

    private func swapSize() {
        (width.text, height.text) = (height.text, width.text)
        validate()
    }

    private func createCanvas() {
        endEditing(true)
        guard let size else { return }
        onCreate(size.0, size.1)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === width { height.becomeFirstResponder() } else { createCanvas() }
        return true
    }

    private static func field(_ value: String) -> UITextField {
        let field = UITextField()
        field.text = value
        field.keyboardType = .numberPad
        field.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        field.borderStyle = .none
        field.backgroundColor = Palette.well
        field.layer.cornerRadius = 8
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        // The unit as far in from the well's right edge as the number is from its left, as the Mac's field has it. The
        // field takes a label on its own at the label's width, so it comes in a view that has the margin too.
        let unit = UILabel()
        unit.text = "px"
        unit.textColor = .secondaryLabel
        unit.sizeToFit()
        let trailing = UIView(frame: CGRect(x: 0, y: 0, width: unit.bounds.width + 12, height: unit.bounds.height))
        trailing.addSubview(unit)
        field.rightView = trailing
        field.rightViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        // As wide as the Mac's field where there's room; the row takes less on a narrow card.
        let width = field.widthAnchor.constraint(equalToConstant: 190)
        width.priority = .defaultHigh
        width.isActive = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private static func labeled(_ title: String, _ field: UITextField) -> UIView {
        let label = UILabel()
        label.text = title.localized
        label.font = .systemFont(ofSize: 15, weight: .medium)
        field.accessibilityLabel = title.localized
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }
}

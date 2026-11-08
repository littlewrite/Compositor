import UIKit

/// The rail as a sheet, for a window with no room for it: the tools as a grid, with the colors they paint in under them.
/// Choosing a tool puts the sheet away, as choosing one from the rail would.
final class ToolGridController: MobileViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                                 UIColorPickerViewControllerDelegate {
    private let session: EditorSession
    private let tools = NavigationTool.allCases.filter { $0 != .idle }
    private let grid = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private let foreground = SwatchButton(size: CGSize(width: 34, height: 34), cornerRadius: 9),
                background = SwatchButton(size: CGSize(width: 34, height: 34), cornerRadius: 9)
    private var pickingBackground = false

    init(session: EditorSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
        title = "Tools".localized
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.window
        view.accessibilityIdentifier = "toolGrid"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel".localized, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        grid.dataSource = self
        grid.delegate = self
        grid.backgroundColor = .clear
        grid.register(ToolCell.self, forCellWithReuseIdentifier: ToolCell.reuseIdentifier)
        grid.contentInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        grid.alwaysBounceVertical = true

        let colors = colorRow()
        for view in [grid, colors] as [UIView] {
            self.view.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: colors.topAnchor),
            colors.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            colors.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            colors.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            colors.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    /// The foreground and background colors, with Swap and Reset, as the rail carries them under the tools.
    private func colorRow() -> UIView {
        let row = UIView()
        let line = UIView()
        line.backgroundColor = Palette.separator
        row.addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false

        for (swatch, isBackground) in [(background, true), (foreground, false)] {
            swatch.accessibilityLabel = isBackground ? "Background color" : "Foreground color"
            swatch.addAction(UIAction { [weak self] _ in self?.chooseColor(background: isBackground) }, for: .primaryActionTriggered)
            row.addSubview(swatch)
            swatch.translatesAutoresizingMaskIntoConstraints = false
        }
        let swap = Self.smallButton("arrow.left.and.right", label: "Swap colors") { [weak self] in self?.session.swapPaletteColors() }
        swap.imageView?.transform = CGAffineTransform(rotationAngle: .pi / 4)
        let reset = Self.smallButton("arrow.counterclockwise", label: "Default colors") { [weak self] in self?.session.resetPaletteColors() }
        let labels = UIStackView(arrangedSubviews: [swap, reset, UIView()])
        labels.axis = .horizontal
        labels.spacing = 12
        row.addSubview(labels)
        labels.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: row.topAnchor), line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor), line.heightAnchor.constraint(equalToConstant: 1 / max(1, view.traitCollection.displayScale)),
            foreground.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            foreground.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            background.leadingAnchor.constraint(equalTo: foreground.trailingAnchor, constant: 12),
            background.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labels.leadingAnchor.constraint(equalTo: background.trailingAnchor, constant: 20),
            labels.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    override func updateProperties() {
        super.updateProperties()
        foreground.color = session.paletteColor(background: false)
        background.color = session.paletteColor(background: true)
        for swatch in [foreground, background] { swatch.isEnabled = session.canEditPalette }
        grid.reloadData()
    }

    // MARK: The grid

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { tools.count }

    func collectionView(_ collectionView: UICollectionView, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let across: CGFloat = collectionView.bounds.width >= 500 ? 8 : 5
        let available = collectionView.bounds.width - 32
        let side = floor((available - (across - 1) * 10) / across)
        return CGSize(width: side, height: side + 18)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ToolCell.reuseIdentifier, for: indexPath) as! ToolCell
        let tool = tools[indexPath.item]
        let selected = session.tool == tool
        let available = ToolRailView.touchTools.contains(tool)
        cell.show(image: ToolRailView.image(for: tool, in: session), title: tool.label.localized,
                  selected: selected, enabled: available && session.document != nil)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tool = tools[indexPath.item]
        guard ToolRailView.touchTools.contains(tool), session.document != nil else { return }
        session.selectTool(tool)
        dismiss(animated: true)
    }

    // MARK: Colors

    private func chooseColor(background isBackground: Bool) {
        let source = isBackground ? background : foreground
        // A mask paints in black or white only; the rail asks which, as the Mac does.
        if session.isMaskSelected {
            let sheet = UIAlertController(title: isBackground ? "Mask background" : "Mask foreground", message: nil,
                                          preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Black · Hide".localized, style: .default) { [weak self] _ in
                self?.session.setPaletteColor(.black, background: isBackground)
            })
            sheet.addAction(UIAlertAction(title: "White · Reveal".localized, style: .default) { [weak self] _ in
                self?.session.setPaletteColor(.white, background: isBackground)
            })
            sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
            sheet.popoverPresentationController?.sourceView = source
            present(sheet, animated: true)
            return
        }
        pickingBackground = isBackground
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        let current = session.paletteColor(background: isBackground)
        picker.selectedColor = UIColor(srgbRed: current.red, green: current.green, blue: current.blue, alpha: 1)
        picker.delegate = self
        picker.modalPresentationStyle = .popover
        picker.popoverPresentationController?.sourceView = source
        present(picker, animated: true)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard let sRGB = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = sRGB.components, c.count >= 3 else { return }
        session.setPaletteColor(PaletteColor(red: min(1, max(0, c[0])), green: min(1, max(0, c[1])), blue: min(1, max(0, c[2]))),
                                background: pickingBackground)
    }

    private static func smallButton(_ symbol: String, label: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        configuration.baseForegroundColor = .secondaryLabel
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }
}

/// One tool in the grid: its icon, and its name under it.
private final class ToolCell: UICollectionViewCell {
    static let reuseIdentifier = "tool"

    private let icon = UIImageView()
    private let caption = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.contentMode = .center
        caption.font = .preferredFont(forTextStyle: .caption2)
        caption.adjustsFontSizeToFitWidth = true
        caption.minimumScaleFactor = 0.7
        caption.textAlignment = .center
        caption.textColor = .secondaryLabel
        contentView.layer.cornerRadius = 10
        contentView.layer.cornerCurve = .continuous
        for view in [icon, caption] as [UIView] {
            contentView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -8),
            caption.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 2),
            caption.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            caption.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(image: UIImage?, title: String, selected: Bool, enabled: Bool) {
        icon.image = image
        caption.text = title
        contentView.backgroundColor = selected ? Palette.selection : .clear
        contentView.layer.borderWidth = selected ? 1 : 0
        contentView.layer.borderColor = Palette.border.cgColor
        alpha = enabled ? 1 : 0.35
        isUserInteractionEnabled = enabled
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}

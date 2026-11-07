import UIKit

/// View › Grid Settings…, as the Mac's sheet: the layout grid's color and style, its lines every so many pixels and
/// their subdivisions. Every change shows on the canvas at once; Cancel puts back what was there. Nothing is saved or
/// undone.
final class GridSettingsController: SizeDialogController {
    private let session: EditorSession
    private let dismissDialog: () -> Void
    private let original: (grid: LayoutGrid, appearance: GridAppearance, shown: Bool)

    private(set) var spacing: Int
    private(set) var subdivisions: Int
    private(set) var appearance: GridAppearance

    private let presets = PopUpButton()
    private let styles = PopUpButton()
    private let customWell = UIColorWell()
    private var customRow: UIView?
    private lazy var opacity = SliderField(caption: "Opacity", unit: "%",
                                           sliderRange: Double(GridAppearance.opacityRange.lowerBound)...Double(GridAppearance.opacityRange.upperBound),
                                           fieldRange: Double(GridAppearance.opacityRange.lowerBound)...Double(GridAppearance.opacityRange.upperBound),
                                           sensitivity: 0.5, sliderWidth: nil)
    private lazy var spacingField = NumberField(caption: "Gridline every", unit: "pixels", width: 90,
                                                range: Double(LayoutGrid.spacingRange.lowerBound)...Double(LayoutGrid.spacingRange.upperBound))
    private lazy var subdivisionField = NumberField(caption: "Subdivisions", width: 90,
                                                    range: Double(LayoutGrid.subdivisionRange.lowerBound)...Double(LayoutGrid.subdivisionRange.upperBound))
    private let note = SizeDialogController.note()

    init(session: EditorSession, dismiss: @escaping () -> Void) {
        self.session = session
        dismissDialog = dismiss
        original = (session.layoutGrid, session.gridAppearance, session.showsGrid)
        spacing = original.grid.spacing
        subdivisions = original.grid.subdivisions
        appearance = original.appearance
        super.init(title: "Grid".localized, confirm: "OK".localized)
        // The grid shows while the dialog is open, changing as it's edited, as the Mac's sheet shows it.
        session.showsGrid = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var valid: Bool {
        LayoutGrid.spacingRange.contains(spacing) && LayoutGrid.subdivisionRange.contains(subdivisions)
            && subdivisions <= spacing
    }
    private var grid: LayoutGrid { LayoutGrid(spacing: spacing, subdivisions: subdivisions) }

    override func viewDidLoad() {
        presets.accessibilityLabel = "Grid Color".localized
        presets.onChoose = { [weak self] in self?.choosePreset(GridAppearance.Preset(rawValue: $0) ?? .lightGray) }
        styles.accessibilityLabel = "Grid Style".localized
        styles.onChoose = { [weak self] in self?.chooseStyle(GridAppearance.Style(rawValue: $0) ?? .lines) }
        customWell.title = "Grid Color".localized
        customWell.supportsAlpha = false
        customWell.selectedColor = UIColor(srgbRed: appearance.customColor.red, green: appearance.customColor.green,
                                           blue: appearance.customColor.blue, alpha: 1)
        customWell.addAction(UIAction { [weak self] _ in
            guard let self, let color = self.customWell.selectedColor else { return }
            self.chooseCustomColor(color)
        }, for: .valueChanged)
        let customRow = OptionControls.row([OptionControls.caption("Custom color", color: .secondaryLabel), customWell])
        self.customRow = customRow

        opacity.onChange = { [weak self] value in self?.setOpacity(value) }
        spacingField.live = true
        spacingField.onChange = { [weak self] value in self?.setSpacing(Int(value.rounded())) }
        subdivisionField.live = true
        subdivisionField.onChange = { [weak self] value in self?.setSubdivisions(Int(value.rounded())) }

        let restore = OptionControls.button("Restore Defaults") { [weak self] in self?.restoreDefaults() }

        for view in [OptionControls.row([OptionControls.caption("Color", color: .secondaryLabel), presets]), customRow,
                     OptionControls.row([OptionControls.caption("Style", color: .secondaryLabel), styles]),
                     opacity, spacingField, subdivisionField, note, restore] as [UIView] {
            content.addArrangedSubview(view)
        }
        super.viewDidLoad()
    }

    override func refresh() {
        presets.show([GridAppearance.Preset.allCases.map(\.rawValue)], chosen: appearance.preset.rawValue)
        styles.show([GridAppearance.Style.allCases.map(\.rawValue)], chosen: appearance.style.rawValue)
        customRow?.isHidden = appearance.preset != .custom
        opacity.show(Double(appearance.opacity))
        spacingField.show(Double(spacing))
        subdivisionField.show(Double(subdivisions))
        confirmButton.isEnabled = valid
        if valid {
            note.text = String(format: "A subdivision every %@ pixels.".localized, SizeDialogController.decimals(Double(grid.step)))
            note.textColor = .secondaryLabel
            session.layoutGrid = grid
        } else {
            note.text = String(format: "Use gridlines every %@–%@ pixels and %@–%@ subdivisions, no more than the pixels between gridlines.".localized,
                               "\(LayoutGrid.spacingRange.lowerBound)", "\(LayoutGrid.spacingRange.upperBound)",
                               "\(LayoutGrid.subdivisionRange.lowerBound)", "\(LayoutGrid.subdivisionRange.upperBound)")
            note.textColor = .systemOrange
        }
        session.gridAppearance = appearance
    }

    func choosePreset(_ preset: GridAppearance.Preset) {
        appearance.preset = preset
        refresh()
        view.setNeedsLayout()
    }
    func chooseStyle(_ style: GridAppearance.Style) {
        appearance.style = style
        refresh()
    }
    func chooseCustomColor(_ color: UIColor) {
        guard let sRGB = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = sRGB.components, c.count >= 3 else { return }
        appearance.customColor = PaletteColor(red: min(1, max(0, c[0])), green: min(1, max(0, c[1])), blue: min(1, max(0, c[2])))
        appearance.preset = .custom
        refresh()
        view.setNeedsLayout()
    }
    func setOpacity(_ value: Double) {
        appearance.opacity = min(GridAppearance.opacityRange.upperBound,
                                 max(GridAppearance.opacityRange.lowerBound, Int(value.rounded())))
        refresh()
    }
    func setSpacing(_ value: Int) {
        spacing = min(LayoutGrid.spacingRange.upperBound, max(LayoutGrid.spacingRange.lowerBound, value))
        refresh()
    }
    func setSubdivisions(_ value: Int) {
        subdivisions = min(LayoutGrid.subdivisionRange.upperBound, max(LayoutGrid.subdivisionRange.lowerBound, value))
        refresh()
    }
    func restoreDefaults() {
        spacing = LayoutGrid().spacing
        subdivisions = LayoutGrid().subdivisions
        // The custom color is kept, so it's still there if Custom is chosen again.
        appearance.preset = GridAppearance().preset
        appearance.style = GridAppearance().style
        appearance.opacity = GridAppearance().opacity
        refresh()
    }

    override func confirm() {
        guard valid else { return }
        session.showsGrid = original.shown
        session.layoutGrid = grid
        session.gridAppearance = appearance
        dismissDialog()
    }
    override func cancel() {
        session.showsGrid = original.shown
        session.layoutGrid = original.grid
        session.gridAppearance = original.appearance
        dismissDialog()
    }
}

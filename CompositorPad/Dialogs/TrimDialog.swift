import UIKit

/// Image › Trim…, as the Mac's sheet: the blank edges around the artwork cut away, those of transparent pixels or of a
/// corner's color, on the sides chosen.
final class TrimDialogController: SizeDialogController {
    private(set) var basedOn = TrimBasedOn.transparentPixels
    private(set) var top = true
    private(set) var bottom = true
    private(set) var left = true
    private(set) var right = true
    private let finish: (TrimOptions?) -> Void

    private let base = PopUpButton()
    private lazy var topBox = side("Top") { [weak self] in self?.top = $0 }
    private lazy var bottomBox = side("Bottom") { [weak self] in self?.bottom = $0 }
    private lazy var leftBox = side("Left") { [weak self] in self?.left = $0 }
    private lazy var rightBox = side("Right") { [weak self] in self?.right = $0 }

    init(finish: @escaping (TrimOptions?) -> Void) {
        self.finish = finish
        super.init(title: "Trim".localized, confirm: "OK".localized)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        base.accessibilityLabel = "Based On".localized
        base.onChoose = { [weak self] in self?.chooseBasedOn(TrimBasedOn(rawValue: $0) ?? .transparentPixels) }
        let note = Self.note("Pixels matching the choice along an edge are cut away, on the sides checked.")
        let firstRow = UIStackView(arrangedSubviews: [topBox, bottomBox])
        let secondRow = UIStackView(arrangedSubviews: [leftBox, rightBox])
        for row in [firstRow, secondRow] {
            row.axis = .horizontal
            row.distribution = .fillEqually
        }
        let sides = UIStackView(arrangedSubviews: [firstRow, secondRow])
        sides.axis = .vertical
        sides.spacing = 8
        for view in [OptionControls.caption("Based On", color: .secondaryLabel), base, note,
                     OptionControls.caption("Trim Away", color: .secondaryLabel), sides] as [UIView] {
            content.addArrangedSubview(view)
        }
        super.viewDidLoad()
    }

    override func refresh() {
        base.show([TrimBasedOn.allCases.map(\.rawValue)], chosen: basedOn.rawValue)
        topBox.isSelected = top
        bottomBox.isSelected = bottom
        leftBox.isSelected = left
        rightBox.isSelected = right
        confirmButton.isEnabled = top || bottom || left || right
    }

    /// A side's checkbox, which refreshes the dialog as it's turned on or off.
    private func side(_ title: String, _ set: @escaping (Bool) -> Void) -> UIButton {
        OptionControls.checkbox(title) { [weak self] on in
            set(on)
            self?.refresh()
        }
    }

    func chooseBasedOn(_ choice: TrimBasedOn) {
        basedOn = choice
        refresh()
    }
    func setTop(_ on: Bool) { top = on; refresh() }
    func setBottom(_ on: Bool) { bottom = on; refresh() }
    func setLeft(_ on: Bool) { left = on; refresh() }
    func setRight(_ on: Bool) { right = on; refresh() }

    override func confirm() {
        guard top || bottom || left || right else { return }
        finish(TrimOptions(basedOn: basedOn, top: top, bottom: bottom, left: left, right: right))
    }
    override func cancel() { finish(nil) }
}

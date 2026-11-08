import UIKit

/// The editor for one of a layer's effects, as the Mac's effect panel: the effect's name with its color, or Stroke's
/// position, beside it, its rows, and Cancel and OK. It stays bound to the layer that opened it, and its changes show
/// on the canvas as they're made.
final class EffectEditorController: AdjustmentEditorController {
    typealias Row = EffectControls.Row

    /// Each effect's rows, as the Mac's effect panel has them.
    static let rows = EffectControls.all

    let selection: LayerEffectSelection
    private var fields: [(row: Row, field: SliderField)] = []
    private let swatch = SwatchButton(size: CGSize(width: 36, height: 18), cornerRadius: 3, inner: 1)
    /// Gradient Overlay's second color.
    private let endSwatch = SwatchButton(size: CGSize(width: 36, height: 18), cornerRadius: 3, inner: 1)
    private let position = OptionControls.segments(["Outside", "Inside"]) { _ in }
    /// Pattern Overlay's pattern, when its editor offers a choice.
    private var patternChoice: (EffectControls.Choice, PopUpButton)?

    init(session: EditorSession, selection: LayerEffectSelection) {
        self.selection = selection
        super.init(session: session, title: selection.kind.displayName)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var kind: LayerEffectKind { selection.kind }

    override var isOpen: Bool { session.effectsEditing == selection }
    override func cancel() { session.finishEffectsEditing(commit: false) }
    override func commit() { session.finishEffectsEditing(commit: true) }
    // The Mac's effect panel has no Preview or Reset: what's set shows as it's set.
    override func previewRow(preview: UIView, reset: UIView) -> [UIView] { [] }
    override var notesSelection: Bool { false }
    override var foot: Foot { .effect }
    override func headingAccessory() -> UIView? {
        switch kind {
        case .stroke: return position
        case .gradientOverlay: return OptionControls.row([swatch, endSwatch], spacing: 6)
        default: return swatch
        }
    }

    override func viewDidLoad() {
        swatch.accessibilityLabel = String(format: "%@ color".localized, kind.displayName)
        swatch.setHelp(String(format: "%@ color".localized, kind.displayName), hint: "Opens the color picker.".localized)
        swatch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.pickerSource = self.swatch
            self.session.openEffectColorPicker(self.kind)
        }, for: .primaryActionTriggered)
        endSwatch.accessibilityLabel = "Gradient end color".localized
        endSwatch.setHelp("Gradient end color".localized, hint: "Opens the color picker.".localized)
        endSwatch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.pickerSource = self.endSwatch
            self.session.openEffectColorPicker(self.kind, end: 1)
        }, for: .primaryActionTriggered)
        position.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let inside = self.position.selectedSegmentIndex == 1
            self.session.changeEffects { $0.stroke?.inside = inside }
        }, for: .valueChanged)
        super.viewDidLoad()
        var captions: [UILabel] = []
        // Stroke's color has a row of its own, under its position.
        if kind == .stroke {
            let label = OptionControls.caption("Color", color: .secondaryLabel)
            captions.append(label)
            // Spaced as a row's slider is from its caption, so the swatch starts where the sliders do.
            content.addArrangedSubview(OptionControls.row([label, swatch, UIView()], spacing: 8))
        }
        if let choice = EffectControls.choices[kind] {
            let popUp = PopUpButton()
            popUp.accessibilityLabel = choice.caption
            popUp.onChoose = { [weak self] name in
                guard let self, let index = choice.titles.firstIndex(of: name) else { return }
                self.session.changeEffects { choice.choose(&$0, index) }
            }
            patternChoice = (choice, popUp)
            content.addArrangedSubview(OptionControls.row([OptionControls.caption(choice.caption, color: .secondaryLabel),
                                                           popUp, UIView()], spacing: 10))
        }
        for row in Self.rows[kind] ?? [] {
            let field = SliderField(caption: row.caption, unit: row.unit, sliderRange: row.slider, fieldRange: row.field,
                                    fieldScale: row.scale, sensitivity: 1 / row.scale, sliderWidth: nil,
                                    fieldWidth: NumberField.width(toShow: row.field.lowerBound * row.scale...row.field.upperBound * row.scale, decimals: 0))
            field.arrowStep = 1
            field.onChange = { [weak self] value in self?.session.changeEffects { row.set(&$0, value) } }
            // A drag, of the slider or the caption, is one undo step, as Layer Opacity's is.
            field.onStart = { [weak self] in self?.session.beginEffectsChange() }
            field.onFinish = { [weak self] in self?.session.finishEffectsChange() }
            // Return gives the keyboard back to the canvas, as in the tools' bar, so ⌘Z and the canvas's keys work
            // straight away; Escape stays the panel's Cancel.
            field.onReturn = { [weak self] in self?.session.canvasFocusRequest += 1 }
            fields.append((row, field))
            content.addArrangedSubview(field)
        }
        SliderField.alignColumns(fields.map(\.field), with: captions)
    }

    override func refresh() {
        let effects = session.editingEffects
        // Undone, or gone with its layer: the window ends the editing, and the editor with it.
        guard effects.contains(kind) else { return }
        for (row, field) in fields {
            if let value = row.get(effects) { field.show(value) }
        }
        if let color = effects.color(kind) { swatch.color = color }
        if let color = effects.color(kind, end: 1) { endSwatch.color = color }
        if let (choice, popUp) = patternChoice {
            popUp.show([choice.titles], chosen: choice.titles[choice.chosen(effects)])
        }
        position.selectedSegmentIndex = effects.stroke?.inside == true ? 1 : 0
    }
}

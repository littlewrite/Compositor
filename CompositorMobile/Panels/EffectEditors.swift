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
    private let position = OptionControls.segments(["Outside", "Inside"]) { _ in }

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
    override func headingAccessory() -> UIView? { kind == .stroke ? position : swatch }

    override func viewDidLoad() {
        swatch.accessibilityLabel = String(format: "%@ color".localized, kind.displayName)
        swatch.setHelp(String(format: "%@ color".localized, kind.displayName), hint: "Opens the color picker.".localized)
        swatch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.pickerSource = self.swatch
            self.session.openEffectColorPicker(self.kind)
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
        position.selectedSegmentIndex = effects.stroke?.inside == true ? 1 : 0
    }
}

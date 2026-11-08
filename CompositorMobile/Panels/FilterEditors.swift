import UIKit

/// The editor for a filter, or an adjustment layer of the same kind, as the Mac's filter panel: a row for each of the
/// filter's settings, then Preview, and Cancel and OK. Like the Mac's, it has no Reset.
final class FilterEditorController: AdjustmentEditorController {
    typealias Row = FilterControls.Row
    typealias Swatch = FilterControls.Swatch
    typealias Control = FilterControls.Control
    static let controls = FilterControls.all
    nonisolated private static func palette(_ color: AdjustmentColor) -> PaletteColor {
        PaletteColor(red: color.red, green: color.green, blue: color.blue)
    }

    /// The kinds the iOS app has this editor for; the Filter and Image menus offer them, and New Adjustment Layer the
    /// adjustments among them. Rim Light has an editor of its own, for its lights.
    static let kinds = Set(controls.keys).union([.rimLight])

    /// Each kind's slider rows, in order.
    static let rows: [FilterKind: [Row]] = controls.mapValues { controls in
        controls.compactMap { if case .slider(let row) = $0 { row } else { nil } }
    }

    let kind: FilterKind
    private var fields: [(row: Row, field: SliderField)] = []
    /// Why the preview couldn't be made, in orange, as the Mac's panel says it.
    private let error = OptionControls.caption("", color: .systemOrange)
    /// Puts the edit's values into the controls other than sliders.
    private var refreshers: [(FilterSettings) -> Void] = []

    init(session: EditorSession, kind: FilterKind) {
        self.kind = kind
        super.init(session: session, title: kind.displayName)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var edit: FilterEdit? { session.filterEdit }
    private func update(_ change: (inout FilterSettings) -> Void) {
        guard var settings = edit?.settings else { return }
        change(&settings)
        session.updateFilter(settings, preview: edit?.preview ?? true)
    }

    override var isOpen: Bool { edit?.kind == kind }
    override var previews: Bool { edit?.preview ?? true }
    override func setPreview(_ on: Bool) {
        guard let edit else { return }
        session.updateFilter(edit.settings, preview: on)
    }
    override func cancel() { session.cancelFilter() }
    override func commit() {
        // OK waits for a slow filter's preview, as the Mac's disabled OK does; Return with it.
        guard canCommit else { return }
        let session = session
        Task { await session.commitFilter() }
    }
    override var canCommit: Bool {
        guard let edit else { return false }
        return !(kind.isAutomatic && (edit.preparing || edit.previewError != nil))
    }
    /// Applying… while OK applies the filter; Working… while a slow one (Remove Background, Content-Aware Fill) works out
    /// its preview, as the Mac's panel says. A quick one says nothing, so the panel doesn't flicker as a slider moves.
    override var activity: Activity? {
        guard let edit else { return nil }
        if edit.committing { return Activity(text: "Applying…", holds: true) }
        if edit.preparing, kind.isAutomatic { return Activity(text: "Working…", holds: false) }
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        var captions: [UILabel] = []
        /// Adds `view` to the controls, showing only while `shown` says so.
        func add(_ view: UIView, shown: ((FilterSettings) -> Bool)?) {
            content.addArrangedSubview(view)
            if let shown { refreshers.append { view.isHidden = !shown($0) } }
        }
        for control in Self.controls[kind] ?? [] {
            switch control {
            case .slider(let row):
                let step = pow(10, Double(row.decimals))
                let field = SliderField(caption: row.caption, unit: row.unit, sliderRange: row.range, fieldRange: row.range,
                                        sensitivity: 1 / step, logarithmic: row.logarithmic, decimals: row.decimals, sliderWidth: nil,
                                        fieldWidth: NumberField.width(toShow: row.range, decimals: row.decimals))
                field.onChange = { [weak self] value in self?.update { $0[keyPath: row.key] = value } }
                field.setHelp(row.help, hint: row.hint)
                if row.track != nil {
                    field.onReset = { [weak self] in self?.update { $0[keyPath: row.key] = FilterSettings()[keyPath: row.key] } }
                    // VoiceOver has Reset among the slider's actions, so that's no hint.
                    field.setHelp(row.help ?? row.caption + ". Double-click to reset.", hint: row.hint)
                }
                fields.append((row, field))
                content.addArrangedSubview(field)
            case .choice(let caption, let titles, let help, let hints, let chosen, let choose, let shown):
                let segments = OptionControls.segments(titles) { [weak self] index in self?.update { choose(&$0, index) } }
                segments.setHelp(help, hints: hints ?? [])
                refreshers.append { segments.selectedSegmentIndex = chosen($0) }
                let views = (caption.map { [OptionControls.caption($0, color: .secondaryLabel)] } ?? []) + [segments, UIView()]
                add(OptionControls.row(views, spacing: 10), shown: shown)
            case .popUp(let caption, let groups, let help, let hint, let chosen, let choose, let shown):
                let popUp = PopUpButton()
                popUp.accessibilityLabel = caption
                popUp.setHelp(help, hint: hint)
                popUp.onChoose = { [weak self] name in self?.update { choose(&$0, name) } }
                refreshers.append { popUp.show(groups, chosen: chosen($0)) }
                add(OptionControls.row([OptionControls.caption(caption, color: .secondaryLabel), popUp, UIView()], spacing: 10), shown: shown)
            case .checkbox(let title, let key, let help, let hint, let shown):
                let box = OptionControls.checkbox(title) { [weak self] on in self?.update { $0[keyPath: key] = on } }
                box.setHelp(help, hint: hint)
                refreshers.append { box.isSelected = $0[keyPath: key] }
                add(OptionControls.row([box, UIView()]), shown: shown)
            case .field(let caption, let key, let help, let hint, let shown):
                let field = UITextField()
                field.borderStyle = .roundedRect
                field.font = .monospacedSystemFont(ofSize: OptionControls.controlFont.pointSize, weight: .regular)
                field.autocorrectionType = .no
                field.autocapitalizationType = .none
                field.spellCheckingType = .no
                field.accessibilityLabel = caption
                field.setHelp(help, hint: hint)
                field.addAction(UIAction { [weak self, weak field] _ in
                    guard let text = field?.text else { return }
                    self?.update { $0[keyPath: key] = text }
                }, for: .editingChanged)
                // Return only ends the typing, as in the Mac's field.
                field.addAction(UIAction { _ in }, for: .editingDidEndOnExit)
                refreshers.append { if !field.isEditing { field.text = $0[keyPath: key] } }
                add(OptionControls.row([OptionControls.caption(caption, color: .secondaryLabel), field], spacing: 10), shown: shown)
            case .color(let caption, let help, let hint, let value, let open):
                let label = OptionControls.caption(caption, color: .secondaryLabel)
                let swatch = SwatchButton(size: CGSize(width: 24, height: 24), cornerRadius: 6)
                swatch.accessibilityLabel = caption
                swatch.setHelp(help, hint: hint)
                swatch.addAction(UIAction { [weak self, weak swatch] _ in
                    guard let self else { return }
                    self.pickerSource = swatch
                    open(self.session)
                }, for: .primaryActionTriggered)
                refreshers.append { swatch.color = Self.palette(value($0)) }
                captions.append(label)
                // Spaced as a row's slider is from its caption, so the swatch starts where the sliders do.
                content.addArrangedSubview(OptionControls.row([label, swatch, UIView()], spacing: 8))
            case .gradient(let colors):
                let bar = GradientBar(height: 20)
                bar.layer.cornerRadius = 4
                bar.layer.cornerCurve = .continuous
                bar.layer.borderWidth = 1
                bar.layer.borderColor = UIColor.black.withAlphaComponent(0.35).cgColor
                bar.clipsToBounds = true
                refreshers.append { bar.colors = colors($0).map(Self.palette) }
                content.addArrangedSubview(bar)
            case .swatches(let ends, let titlesFirst, let shown):
                let pairs = ends.map { end -> UIView in
                    let swatch = SwatchButton(size: CGSize(width: 24, height: 24), cornerRadius: 6)
                    swatch.accessibilityLabel = end.title + " color"
                    swatch.setHelp("Choose the \(end.title.lowercased()) color", hint: "Opens the color picker.")
                    swatch.addAction(UIAction { [weak self, weak swatch] _ in
                        guard let self else { return }
                        self.pickerSource = swatch
                        end.open(self.session)
                    }, for: .primaryActionTriggered)
                    refreshers.append { swatch.color = Self.palette(end.value($0)) }
                    let title = OptionControls.caption(end.title, color: .label)
                    return OptionControls.row(titlesFirst ? [title, swatch] : [swatch, title], spacing: 8)
                }
                add(OptionControls.row(pairs + [UIView()], spacing: titlesFirst ? 18 : 20), shown: shown)
            case .heading(let title):
                let label = OptionControls.caption(title, color: .label)
                label.font = .preferredFont(forTextStyle: .headline)
                content.addArrangedSubview(label)
            case .text(let text):
                let label = OptionControls.caption(text, color: .label)
                label.numberOfLines = 0
                content.addArrangedSubview(label)
            case .action(let title, let help, let hint, let run):
                let button = OptionControls.button(title) { [weak self] in
                    guard let self else { return }
                    run(self.session)
                }
                button.setHelp(help, hint: hint)
                content.addArrangedSubview(OptionControls.row([button, UIView()]))
            case .note(let text, let shown):
                let note = OptionControls.caption(text, color: .secondaryLabel)
                note.numberOfLines = 0
                add(note, shown: shown)
            }
        }
        SliderField.alignColumns(fields.map(\.field), with: captions)
        error.numberOfLines = 0
        notes.insertArrangedSubview(error, at: 0)
    }

    override func refresh() {
        guard let settings = edit?.settings else { return }
        for (row, field) in fields {
            field.show(settings[keyPath: row.key])
            field.isHidden = row.shown?(settings) == false
            if let track = row.track { field.track = track(settings) }
        }
        for refresh in refreshers { refresh(settings) }
        error.text = edit?.previewError
        error.isHidden = edit?.previewError == nil
    }
}

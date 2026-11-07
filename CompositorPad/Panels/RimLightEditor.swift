import UIKit

/// Filter › Rim Light, as the Mac's panel: its glow, then each light's color, angle, strength, width and choke, with
/// room for up to three, and a button to add another. The lights change under the controls as they're added and taken
/// away, so the panel is built again from the edit's lights whenever the set changes.
final class RimLightEditorController: AdjustmentEditorController {
    private let glow = SliderField(caption: "Glow", unit: "%", sliderRange: 0...100, fieldRange: 0...100, sensitivity: 1,
                                   logarithmic: false, decimals: 0, sliderWidth: nil, fieldWidth: NumberField.width(toShow: 0...100, decimals: 0))
    private let lights = UIStackView()
    private let add = OptionControls.button("Add Light") {}
    private var rows: [LightRow] = []

    /// One light's controls, kept so a refresh can put the edit's values into them without rebuilding.
    private struct LightRow {
        let id: UUID
        let angle: SliderField
        let strength: SliderField
        let width: SliderField
        let choke: SliderField
        let swatch: SwatchButton
        let remove: UIButton
    }

    init(session: EditorSession) { super.init(session: session, title: "Rim Light") }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var edit: FilterEdit? { session.filterEdit }
    private func update(_ change: (inout RimLightSettings) -> Void) {
        guard var settings = edit?.settings else { return }
        change(&settings.rimLight)
        session.updateFilter(settings, preview: edit?.preview ?? true)
    }

    override var isOpen: Bool { edit?.kind == .rimLight }
    override var previews: Bool { edit?.preview ?? true }
    override func setPreview(_ on: Bool) {
        guard let edit else { return }
        session.updateFilter(edit.settings, preview: on)
    }
    override func cancel() { session.cancelFilter() }
    override func commit() {
        let session = session
        Task { await session.commitFilter() }
    }
    override var activity: Activity? { edit?.committing == true ? Activity(text: "Applying…", holds: true) : nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        glow.onChange = { [weak self] value in self?.update { $0.glow = value } }
        glow.setHelp("Let the lights glow in the air around the subject, blending them into the background",
                     hint: "Lets the lights glow in the air around the subject.")
        add.addAction(UIAction { [weak self] _ in self?.addLight() }, for: .primaryActionTriggered)
        lights.axis = .vertical
        lights.spacing = 16
        content.addArrangedSubview(glow)
        content.addArrangedSubview(lights)
        content.addArrangedSubview(OptionControls.row([add, UIView()]))
        rebuild()
    }

    override func refresh() {
        guard let rim = edit?.settings.rimLight else { return }
        if rows.map(\.id) != rim.lights.map(\.id) {
            rebuild()
        } else {
            show(rim)
        }
    }

    /// Takes the lights away and builds them again, for a light added, removed, or put back by Undo.
    private func rebuild() {
        lights.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        guard let rim = edit?.settings.rimLight else { return }
        for (index, light) in rim.lights.enumerated() {
            let id = light.id
            let row = LightRow(
                id: id,
                angle: slider("Angle", unit: "°", range: -180...180,
                              help: "Where the light comes from, behind the subject: 0° from the right, 90° from above") { [weak self] value in
                    self?.update { $0[light: id].angle = value }
                },
                strength: slider("Strength", unit: "%", range: 0...100, help: nil) { [weak self] value in
                    self?.update { $0[light: id].strength = value }
                },
                width: slider("Width", unit: "%", range: 0...100,
                              help: "How far the light wraps around the subject's edges") { [weak self] value in
                    self?.update { $0[light: id].width = value }
                },
                choke: slider("Choke", unit: "%", range: 0...100,
                              help: "How the light ends on the inside: low feathers it off softly from the edge, high holds it bright and ends it crisply") { [weak self] value in
                    self?.update { $0[light: id].choke = value }
                },
                swatch: SwatchButton(size: CGSize(width: 24, height: 24), cornerRadius: 6),
                remove: removeButton())
            row.swatch.accessibilityLabel = String(format: "Light %@ color".localized, "\(index + 1)")
            row.swatch.setHelp("Choose this light's color", hint: "Opens the color picker for this light.")
            let swatch = row.swatch
            swatch.addAction(UIAction { [weak self, weak swatch] _ in
                guard let self else { return }
                self.pickerSource = swatch
                self.session.openRimLightColorPicker(index: index)
            }, for: .primaryActionTriggered)
            row.remove.accessibilityLabel = "Remove this light".localized
            row.remove.setHelp("Remove this light", hint: nil)
            row.remove.addAction(UIAction { [weak self] _ in self?.removeLight(id) }, for: .primaryActionTriggered)

            let title = OptionControls.caption("Light \(index + 1)", color: .label)
            title.font = .preferredFont(forTextStyle: .headline)
            let heading = OptionControls.row([title, UIView(), row.swatch, row.remove], spacing: 10)
            let block = UIStackView(arrangedSubviews: [heading, row.angle, row.strength, row.width, row.choke])
            block.axis = .vertical
            block.spacing = 14
            lights.addArrangedSubview(block)
            rows.append(row)
        }
        show(rim)
    }

    private func show(_ rim: RimLightSettings) {
        glow.show(rim.glow)
        for row in rows {
            guard let light = rim.lights.first(where: { $0.id == row.id }) else { continue }
            row.angle.show(light.angle)
            row.strength.show(light.strength)
            row.width.show(light.width)
            row.choke.show(light.choke)
            row.swatch.color = PaletteColor(red: light.color.red, green: light.color.green, blue: light.color.blue)
            row.remove.isHidden = rim.lights.count <= 1
        }
        add.isHidden = rim.lights.count >= RimLightSettings.maximumLights
    }

    private func addLight() {
        update { $0.lights.append($0.nextLight) }
        rebuild()
    }

    private func removeLight(_ id: UUID) {
        // A color still being picked belongs to the lights as they were numbered.
        if case .rimLight = session.colorPicker?.target { session.closeColorPicker(commit: true) }
        update { $0.lights.removeAll { $0.id == id } }
        rebuild()
    }

    /// A row's slider, telling the change as it's made.
    private func slider(_ caption: String, unit: String?, range: ClosedRange<Double>, help: String?,
                        _ change: @escaping (Double) -> Void) -> SliderField {
        let field = SliderField(caption: caption, unit: unit, sliderRange: range, fieldRange: range, sensitivity: 1,
                                logarithmic: false, decimals: 0, sliderWidth: nil,
                                fieldWidth: NumberField.width(toShow: range, decimals: 0))
        field.onChange = change
        field.setHelp(help, hint: help)
        return field
    }

    private func removeButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "minus.circle")
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: 32),
                                     button.heightAnchor.constraint(equalToConstant: 32)])
        return button
    }
}

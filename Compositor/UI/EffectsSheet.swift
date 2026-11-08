import SwiftUI

/// One effect's controls, bound to the layer that opened the panel. Changes preview on the canvas.
struct EffectsSheet: View {
    @Bindable var session: EditorSession
    let kind: LayerEffectKind

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if session.editingEffects.contains(kind) {
                controls
                if kind == .stroke { position }
            }
            Divider()
            HStack {
                Button("Cancel") { session.finishEffectsEditing(commit: false) }
                    .configuredNativeShortcut(.escape)
                Spacer()
                Button("OK") { session.finishEffectsEditing(commit: true) }
                    .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
            }
        }
        .padding(20).frame(width: 340).fixedSize()
        // The picker previews its working color on the layer while it is open.
        .onChange(of: session.colorPicker?.color) { _, _ in session.previewEffectColor() }
    }

    private var header: some View {
        HStack {
            Text(kind.displayName).font(.headline)
            Spacer()
            if session.editingEffects.contains(kind) { swatch(kind) }
        }
    }

    /// The effect's rows, from the table both panels read.
    @ViewBuilder private var controls: some View {
        let effects = session.editingEffects
        ForEach(Array((EffectControls.all[kind] ?? []).enumerated()), id: \.offset) { _, row in
            if let value = row.get(effects) {
                slider(row.caption, value: Binding(get: { CGFloat(value) * CGFloat(row.scale) },
                                                   set: { shown in session.changeEffects { row.set(&$0, Double(shown) / row.scale) } }),
                       range: CGFloat(row.slider.lowerBound * row.scale)...CGFloat(row.slider.upperBound * row.scale),
                       inputRange: CGFloat(row.field.lowerBound * row.scale)...CGFloat(row.field.upperBound * row.scale),
                       unit: row.unit)
            }
        }
    }

    /// Stroke's position, which its rows don't hold: the effect's color sits beside its name instead.
    private var position: some View {
        HStack(spacing: 10) {
            Text("Position").frame(width: 64, alignment: .leading)
            Picker("Position", selection: Binding(get: { session.editingEffects.stroke?.inside ?? false }, set: { inside in
                session.changeEffects { $0.stroke?.inside = inside }
            })) {
                Text("Outside").tag(false)
                Text("Inside").tag(true)
            }.pickerStyle(.segmented).labelsHidden().fixedSize()
            Spacer()
        }
    }

    /// The effect's color, opened in the app's own picker.
    private func swatch(_ kind: LayerEffectKind) -> some View {
        let color = session.editingEffects.color(kind)
        return Button { session.openEffectColorPicker(kind) } label: {
            ColorSwatch(color: Color(red: Double(color?.red ?? 0), green: Double(color?.green ?? 0), blue: Double(color?.blue ?? 0)))
        }
        .buttonStyle(.plain)
        .help(kind.rawValue + " color")
        .accessibilityLabel(kind.rawValue + " color")
    }

    private func slider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>,
                        inputRange: ClosedRange<CGFloat>? = nil, unit: String) -> some View {
        let limits = inputRange ?? range
        let setAmount: (Double) -> Void = { amount in
            guard amount.isFinite else { return }
            value.wrappedValue = min(limits.upperBound, max(limits.lowerBound, CGFloat(amount)))
        }
        return HStack(spacing: 10) {
            Text(title).frame(width: 64, alignment: .leading)
                .scrubbable(sensitivity: 1, value: value, range: limits)
            // A manually entered larger value stays intact; only the thumb is pinned
            // to the end of the slider until the user drags it again.
            Slider(value: Binding(get: { min(range.upperBound, max(range.lowerBound, value.wrappedValue)) },
                                  set: { value.wrappedValue = $0 }), in: range)
            TextField(title, value: Binding(get: { Double(value.wrappedValue) },
                                            set: setAmount),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .arrowSteps(value: { Double(value.wrappedValue) },
                            change: setAmount)
            // A column the same width for every unit, so all the sliders end together and the units meet OK's edge.
            Text(unit).frame(width: 16, alignment: .trailing).padding(.leading, -8)
        }
    }
}

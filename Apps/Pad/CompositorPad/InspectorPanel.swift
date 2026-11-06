import SwiftUI

struct InspectorPanel: View {
    @ObservedObject var session: PadSession

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $session.inspectorTab) {
                Text("Layers").tag(0)
                Text("Adjust").tag(1)
                Text("Filters").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            switch session.inspectorTab {
            case 0:
                layers
            case 1:
                AdjustmentsPane(session: session)
            default:
                FiltersPane(session: session)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var layers: some View {
        VStack(spacing: 0) {
            List {
                ForEach(session.layers.reversed()) { layer in
                    LayerRow(session: session, layer: layer)
                }
            }
            .listStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    session.addBlankLayer()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add layer")
                .accessibilityIdentifier("AddLayer")

                Button {
                    session.duplicateActiveLayer()
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .accessibilityLabel("Duplicate layer")
                .accessibilityIdentifier("DuplicateLayer")

                Button(role: .destructive) {
                    session.deleteActiveLayer()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(session.layers.count <= 1)
                .accessibilityLabel("Delete layer")
                .accessibilityIdentifier("DeleteLayer")

                Spacer()

                Button {
                    session.moveActiveLayer(up: true)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .accessibilityLabel("Move layer up")

                Button {
                    session.moveActiveLayer(up: false)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .accessibilityLabel("Move layer down")
            }
            .font(.footnote)
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("Blend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Blend mode", selection: activeBlendMode) {
                        ForEach(LayerBlendMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("BlendModePicker")
                }

                HStack(spacing: 10) {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: activeOpacity, in: 0...1) { editing in
                        if editing { session.beginEdit() } else { session.endEdit() }
                    }
                    Text("\(Int((activeOpacity.wrappedValue * 100).rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }

                HStack {
                    Button {
                        session.fit()
                    } label: {
                        Label("Fit canvas", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        session.clearStrokes()
                    } label: {
                        Label("Clear strokes", systemImage: "trash")
                    }
                }
                .font(.footnote)
                .buttonStyle(.bordered)
            }
            .padding(14)
        }
    }

    private var activeOpacity: Binding<Double> {
        Binding(
            get: { session.layer(session.activeLayerID)?.opacity ?? 1 },
            set: { session.setOpacity($0, for: session.activeLayerID) })
    }

    private var activeBlendMode: Binding<LayerBlendMode> {
        Binding(
            get: { session.layer(session.activeLayerID)?.blendMode ?? .normal },
            set: { session.setBlendMode($0, for: session.activeLayerID) })
    }
}

private struct LayerRow: View {
    @ObservedObject var session: PadSession
    let layer: PadLayer

    var body: some View {
        HStack(spacing: 10) {
            Button {
                session.setVisible(!layer.isVisible, for: layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 14))
                    .frame(width: 30, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)

            RoundedRectangle(cornerRadius: 5)
                .fill(layer.swatch)
                .frame(width: 38, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.15)))

            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name).font(.subheadline.weight(.medium))
                Text(layer.subtitle).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            if !layer.adjustments.isIdentity {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if session.activeLayerID == layer.id {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { session.activeLayerID = layer.id }
        .listRowBackground(session.activeLayerID == layer.id
            ? Color.accentColor.opacity(0.22)
            : Color.clear)
    }
}

private struct AdjustmentsPane: View {
    @ObservedObject var session: PadSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adjustments")
                            .font(.subheadline.weight(.semibold))
                        Text(session.layer(session.activeLayerID)?.name ?? "No layer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset") {
                        session.resetAdjustments(for: session.activeLayerID)
                    }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    .disabled(session.adjustments(for: session.activeLayerID).isIdentity)
                }

                control("Exposure", \.exposure, -2...2)
                control("Contrast", \.contrast, -1...1)
                control("Saturation", \.saturation, -1...1)
                control("Temperature", \.temperature, -1...1)
                blurControl

                Toggle("Black & White", isOn: flag(\.mono))
                    .font(.caption)
                Toggle("Invert", isOn: flag(\.invert))
                    .font(.caption)

                Divider()

                Text("Adjustments apply to the selected layer and stay with it when the window changes shape.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func control(_ title: String,
                         _ keyPath: WritableKeyPath<LayerAdjustments, Double>,
                         _ range: ClosedRange<Double>) -> some View {
        let value = binding(keyPath)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%+.2f", value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range) { editing in
                if editing { session.beginEdit() } else { session.endEdit() }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<LayerAdjustments, Double>) -> Binding<Double> {
        Binding(
            get: { session.adjustments(for: session.activeLayerID)[keyPath: keyPath] },
            set: { session.setAdjustment(keyPath, value: $0, for: session.activeLayerID) }
        )
    }

    private func flag(_ keyPath: WritableKeyPath<LayerAdjustments, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.adjustments(for: session.activeLayerID)[keyPath: keyPath] },
            set: { session.setAdjustmentFlag(keyPath, value: $0, for: session.activeLayerID) }
        )
    }

    private var blurControl: some View {
        let value = binding(\.blur)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Blur").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f px", value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...20) { editing in
                if editing { session.beginEdit() } else { session.endEdit() }
            }
        }
    }
}

private struct FiltersPane: View {
    @ObservedObject var session: PadSession

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filters")
                        .font(.subheadline.weight(.semibold))
                    Text(session.layer(session.activeLayerID)?.name ?? "No layer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PadFilter.all) { filter in
                        filterButton(filter)
                    }
                }

                Divider()

                Text("A preset writes the same layer adjustments the Adjust tab shows.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func filterButton(_ filter: PadFilter) -> some View {
        let selected = session.adjustments(for: session.activeLayerID) == filter.adjustments
        return Button {
            session.apply(filter)
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: filter.colors,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(height: 58)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.12),
                                          lineWidth: selected ? 2 : 1)
                    }
                Text(filter.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.name)
        .accessibilityIdentifier("Filter\(filter.id)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

import SwiftUI

struct ImageSizeSheet: View {
    let document: CanvasDocument
    let finish: (ImageSizeOptions?) -> Void
    @State private var draft: ImageSizeDraft

    init(document: CanvasDocument, finish: @escaping (ImageSizeOptions?) -> Void) {
        self.document = document
        self.finish = finish
        _draft = State(initialValue: ImageSizeDraft(width: document.width, height: document.height, resolution: document.resolution))
    }

    /// The width or height in the unit chosen, reading and writing the draft the iOS dialog uses too.
    private func dimension(_ widthAxis: Bool) -> Binding<Double> {
        Binding(get: { draft.displayed(widthAxis: widthAxis) }, set: { draft.set($0, widthAxis: widthAxis) })
    }

    private var resolutionBinding: Binding<Double> {
        Binding(get: { draft.resolution }, set: { draft.setResolution($0) })
    }

    var body: some View { sheet.roundedControls() }
    @ViewBuilder private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Image Size").font(.title2.bold())
            Text("Current: \(document.width) × \(document.height) pixels").foregroundStyle(.secondary)
            Picker("Units", selection: $draft.unit) {
                ForEach(draft.units, id: \.self) { Text($0.rawValue) }
            }
            HStack {
                Text("Width").frame(width: 75, alignment: .leading)
                    .scrubbable(sensitivity: draft.scrubSensitivity(widthAxis: true),
                                value: dimension(true), range: draft.scrubRange(widthAxis: true), step: 1)
                    .disabled(!draft.canScrubDimensions)
                TextField("Width", value: dimension(true), format: .number.precision(.fractionLength(0...3)))
            }
            HStack {
                Text("Height").frame(width: 75, alignment: .leading)
                    .scrubbable(sensitivity: draft.scrubSensitivity(widthAxis: false),
                                value: dimension(false), range: draft.scrubRange(widthAxis: false), step: 1)
                    .disabled(!draft.canScrubDimensions)
                TextField("Height", value: dimension(false), format: .number.precision(.fractionLength(0...3)))
            }
            Toggle("Lock aspect ratio", isOn: $draft.locked).disabled(!draft.resample)
            HStack {
                Text("Resolution").scrubbable(sensitivity: 1, value: resolutionBinding, range: 1...9600, step: 1)
                TextField("Resolution", value: resolutionBinding, format: .number.precision(.fractionLength(0...3)))
                Text("pixels/inch").foregroundStyle(.secondary)
            }
            Toggle("Resample", isOn: Binding(get: { draft.resample }, set: { draft.setResample($0) }))
            if draft.resample {
                Picker("Sampling", selection: $draft.sampling) {
                    ForEach(LayerSampling.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text("Resizes layer pixels and applies existing transforms. Undo restores the originals.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Only print dimensions and resolution change. Pixels stay unchanged.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text(draft.valid
                 ? "Result: \(Int(draft.width.rounded())) × \(Int(draft.height.rounded())) pixels"
                 : "Use 1–\(DocumentLimits.maxSide.formatted()) pixels per side, up to \(DocumentLimits.maxSurfaceMegapixels) megapixels, and 1–9,600 pixels/inch.")
                .foregroundStyle(draft.valid ? Color.secondary : Color.orange).font(.callout)
            HStack {
                Button("Cancel") { finish(nil) }.configuredNativeShortcut(.escape)
                Spacer()
                Button("Resize") { finish(draft.options) }.configuredNativeShortcut(.return).disabled(!draft.valid)
            }
        }.textFieldStyle(.roundedBorder).padding(24).frame(width: 430)
    }
}

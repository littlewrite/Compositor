import SwiftUI
import CompositorCore

struct ToolOptionsBar: View {
    @ObservedObject var session: PadSession
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Label(session.tool.title, systemImage: session.tool.symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: compact ? 84 : 110, alignment: .leading)

            Divider().frame(height: compact ? 18 : 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 12 : 16) {
                    options
                }
                .padding(.trailing, 8)
            }

            if session.platform.modifiers.offersOnScreenModifiers {
                modifierChips
            }
        }
        .padding(.horizontal, compact ? 10 : 16)
        .frame(height: compact ? 44 : 50)
        .background(.bar)
    }

    @ViewBuilder
    private var options: some View {
        switch session.tool {
        case .brush, .eraser:
            scrub("Size", value: $session.brushSize, range: 1...400, width: 150) { "\(Int($0)) px" }
            scrub("Hardness", value: $session.brushHardness, range: 0...1, width: 90) { "\(Int($0 * 100))%" }
            scrub("Opacity", value: $session.brushOpacity, range: 0...1, width: 90) { "\(Int($0 * 100))%" }
            ColorPicker("Brush color", selection: $session.brushColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40)
            Button("Clear") { session.clearStrokes() }
                .font(.footnote)
                .buttonStyle(.bordered)
        case .hand, .zoom:
            Text("Drag to pan · Pinch to zoom")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .move:
            Text("Drag the canvas to move the selected layer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .crop:
            Button("Cancel") { session.cancelCrop() }
                .font(.footnote)
                .buttonStyle(.bordered)
                .disabled(session.cropRect == nil)
                .accessibilityIdentifier("CropCancel")
            Button("Apply") { session.applyCrop() }
                .font(.footnote)
                .buttonStyle(.borderedProminent)
                .disabled(session.cropRect == nil)
                .accessibilityIdentifier("CropApply")
            Text(session.cropRect == nil
                 ? "Drag a rectangle on the canvas to crop"
                 : "Apply to crop the document to the rectangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .gradient:
            ColorPicker("Gradient color", selection: $session.brushColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40)
            Text("Drag on the canvas to place a gradient")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .type:
            Button("Add text…") { session.sheet = .text }
                .font(.footnote)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("AddTextButton")
        case .eyedropper:
            ColorPicker("Picked color", selection: $session.brushColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40)
            Text("Tap the canvas to pick a color")
                .font(.footnote)
                .foregroundStyle(.secondary)
        default:
            Text("Options for this tool arrive with the port")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// The iPad's stand-in for held modifier keys. It reads and writes through
    /// `PlatformServices`, so the same bar works on a platform whose modifiers come from a keyboard.
    private var modifierChips: some View {
        HStack(spacing: 6) {
            chip(.shift, "⇧", "Constrain")
            chip(.option, "⌥", "Erase")
            chip(.command, "⌘", "Command")
        }
    }

    private func chip(_ modifier: ModifierSet, _ label: String, _ title: String) -> some View {
        let isOn = session.platform.modifiers.active.contains(modifier)
        return Button {
            session.toggleModifier(modifier)
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(width: 34, height: 30)
                .foregroundStyle(isOn ? Color.white : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Color.accentColor : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func scrub(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                       width: CGFloat, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
                .frame(width: width)
            Text(format(value.wrappedValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
        }
    }
}

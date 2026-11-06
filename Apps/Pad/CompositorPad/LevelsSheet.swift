import SwiftUI

struct LevelsSheet: View {
    @ObservedObject var session: PadSession

    var body: some View {
        VStack(spacing: 18) {
            Text("Levels")
                .font(.title3.weight(.semibold))

            Histogram()
                .frame(height: 96)
                .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 8))

            level("Black point", $session.levels.black, 0...0.98)
            level("Gamma", $session.levels.gamma, 0.1...3)
            level("White point", $session.levels.white, 0.02...1)

            HStack {
                Button("Reset") {
                    session.beginEdit()
                    session.levels = PadLevels()
                    session.endEdit()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") { session.sheet = nil }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("LevelsDone")
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func level(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
}

private struct Histogram: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<64, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: max(2, geo.size.height * barHeight(index)))
                }
            }
            .padding(8)
        }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let x = Double(index) / 63
        let first = exp(-pow((x - 0.15) / 0.10, 2)) * 0.35
        let second = exp(-pow((x - 0.42) / 0.18, 2)) * 0.65
        let third = exp(-pow((x - 0.83) / 0.14, 2)) * 0.22
        return CGFloat(min(1, 0.12 + first + second + third))
    }
}

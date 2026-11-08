import SwiftUI

struct CurvesControls: View {
    @Binding var settings: CurvesSettings
    @State private var selected: Int?
    @State private var dragging: Int?
    private var points: [CurvePoint] { settings.channels[settings.channel.index] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Channel", selection: $settings.channel) {
                ForEach(LevelsChannel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.onChange(of: settings.channel) { _, _ in selected = nil; dragging = nil }
            Canvas { context, size in
                func position(_ p: CurvePoint) -> CGPoint { CGPoint(x: p.x/255*size.width, y: (1-p.y/255)*size.height) }
                var grid = Path()
                for i in 0...4 {
                    let f = CGFloat(i)/4
                    grid.move(to: CGPoint(x: f*size.width, y: 0)); grid.addLine(to: CGPoint(x: f*size.width, y: size.height))
                    grid.move(to: CGPoint(x: 0, y: f*size.height)); grid.addLine(to: CGPoint(x: size.width, y: f*size.height))
                }
                context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
                var line = Path()
                for x in 0...255 {
                    let p = position(CurvePoint(x: Double(x), y: settings.value(Double(x), channel: settings.channel.index)))
                    if x == 0 { line.move(to: p) } else { line.addLine(to: p) }
                }
                context.stroke(line, with: .color(.white), lineWidth: 2)
                for (i, point) in points.enumerated() {
                    let p = position(point)
                    context.fill(Path(ellipseIn: CGRect(x: p.x-4, y: p.y-4, width: 8, height: 8)), with: .color(selected == i ? .accentColor : .white))
                }
            }
            .frame(height: 260).background(Color.black.opacity(0.35))
            .contentShape(Rectangle())
            .overlay { GeometryReader { geometry in
                Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    let x = min(255, max(0, Double(event.location.x/geometry.size.width)*255))
                    let y = min(255, max(0, 255-Double(event.location.y/geometry.size.height)*255))
                    var p = points
                    if dragging == nil {
                        dragging = CurveEditing.press(&p, x: x, y: y)
                        if p != points { settings.channels[settings.channel.index] = p }
                    }
                    guard let i = dragging else { return }
                    selected = i
                    CurveEditing.drag(&p, index: i, x: x, y: y)
                    settings.channels[settings.channel.index] = p
                }.onEnded { _ in dragging = nil })
            } }
            Text("Click to add a point. Drag to adjust.").font(.caption).foregroundStyle(.secondary)
            HStack {
                if let selected, points.indices.contains(selected) {
                    Text("Input \(Int(points[selected].x)) · Output \(Int(points[selected].y))").monospacedDigit()
                }
                Spacer()
                Button("Remove point") {
                    if let selected, selected > 0, selected < points.count-1 { settings.channels[settings.channel.index].remove(at: selected); self.selected = nil }
                }.disabled(selected == nil || selected == 0 || selected == points.count-1)
            }
            Button("Reset curve") { settings.channels[settings.channel.index] = [CurvePoint(x: 0,y: 0), CurvePoint(x: 255,y: 255)]; selected = nil }
        }
    }
}

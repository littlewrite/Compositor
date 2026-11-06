import SwiftUI
import CompositorCore

struct ToolRail: View {
    @ObservedObject var session: PadSession
    var compact: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: compact ? 3 : 4) {
                ForEach(PadTool.allCases) { tool in
                    toolButton(tool)
                    if tool == .crop || tool == .type {
                        Divider().frame(width: compact ? 22 : 28).padding(.vertical, compact ? 2 : 3)
                    }
                }
            }
            .padding(.vertical, compact ? 8 : 10)
        }
        .frame(width: compact ? 48 : 58)
        .background(.ultraThinMaterial)
    }

    private func toolButton(_ tool: PadTool) -> some View {
        Button {
            session.tool = tool
            session.platform.haptics.selectionChanged()
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: compact ? 16 : 18, weight: .medium))
                .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                .foregroundStyle(session.tool == tool ? Color.white : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(session.tool == tool ? Color.accentColor : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(session.tool == tool ? [.isSelected] : [])
    }
}

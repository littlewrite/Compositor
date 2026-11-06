import SwiftUI

@MainActor
protocol ShellStrategy {
    func makeBody(session: PadSession, context: LayoutContext) -> AnyView
}

struct CanvasFirstStrategy: ShellStrategy {
    func makeBody(session: PadSession, context: LayoutContext) -> AnyView {
        AnyView(CanvasFirstShell(session: session, context: context))
    }
}

struct RailStrategy: ShellStrategy {
    func makeBody(session: PadSession, context: LayoutContext) -> AnyView {
        AnyView(RailShell(session: session, context: context))
    }
}

struct StudioStrategy: ShellStrategy {
    func makeBody(session: PadSession, context: LayoutContext) -> AnyView {
        AnyView(StudioShell(session: session, context: context))
    }
}

enum ShellStrategyFactory {
    @MainActor
    static func strategy(for context: LayoutContext) -> any ShellStrategy {
        switch context.shell {
        case .canvasFirst: return CanvasFirstStrategy()
        case .rail: return RailStrategy()
        case .studio: return StudioStrategy()
        }
    }
}

struct AdaptiveShell: View {
    @ObservedObject var session: PadSession
    let context: LayoutContext

    var body: some View {
        ShellStrategyFactory.strategy(for: context)
            .makeBody(session: session, context: context)
    }
}

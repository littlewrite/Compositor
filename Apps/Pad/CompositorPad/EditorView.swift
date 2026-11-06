import SwiftUI
import UniformTypeIdentifiers
import CompositorCore

struct EditorView: View {
    let platform: PlatformServices
    @StateObject private var session: PadSession
    @State private var isDropTargeted = false
    @State private var didApplyInitialInspector = false

    init(platform: PlatformServices) {
        self.platform = platform
        _session = StateObject(wrappedValue: PadSession(platform: platform))
    }

    var body: some View {
        GeometryReader { geometry in
            let context = LayoutContext(size: geometry.size)

            VStack(spacing: 0) {
                EditorTopBar(session: session, context: context)
                Divider()
                AdaptiveShell(session: session, context: context)
            }
            .background(Color(white: 0.1))
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .onAppear { applyInitialInspector(for: context) }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            importProviders(providers)
            return true
        }
        .task {
            await session.autoImportDocumentsIfRequested()
        }
        .sheet(item: $session.sheet) { sheet in
            PadSheetView(session: session, sheet: sheet)
        }
    }

    /// A wide window starts with the inspector pinned; a compact one starts with it closed.
    /// This runs once, so resizing never overrides what the person chose.
    private func applyInitialInspector(for context: LayoutContext) {
        guard !didApplyInitialInspector else { return }
        didApplyInitialInspector = true
        session.showsInspector = context.shell == .studio
    }

    /// Files dragged from the Files app or from the Mac's Finder onto the simulator.
    private func importProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let direct = item as? URL {
                    url = direct
                }
                guard let url else { return }
                Task { @MainActor in
                    await session.importImage(at: url)
                }
            }
        }
    }
}

private struct EditorTopBar: View {
    @ObservedObject var session: PadSession
    let context: LayoutContext

    private var usesWideLabels: Bool {
        !context.isShort && context.size.width >= 900
    }

    var body: some View {
        HStack(spacing: context.usesCompactChrome ? 8 : 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: context.usesCompactChrome ? 15 : 17, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Untitled.comp")
                    .font(context.usesCompactChrome ? .subheadline.weight(.semibold) : .headline)
                if !context.usesCompactChrome {
                    Text("1600 × 1200 · RGB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            Button {
                session.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!session.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .accessibilityLabel("Undo")
            .accessibilityIdentifier("UndoButton")

            Button {
                session.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
            .disabled(!session.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .accessibilityLabel("Redo")
            .accessibilityIdentifier("RedoButton")

            Button {
                importImage()
            } label: {
                if usesWideLabels {
                    Label("Import", systemImage: "photo.badge.plus")
                } else {
                    Image(systemName: "photo.badge.plus")
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Import")

            if !context.usesCompactChrome {
                Button {
                    session.fit()
                } label: {
                    if usesWideLabels {
                        Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    } else {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Fit canvas")
            }

            if usesWideLabels {
                Text("\(Int((session.viewport.zoom * 100).rounded()))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            if !context.usesCompactChrome {
                Button {
                    session.sheet = .levels
                } label: {
                    if usesWideLabels {
                        Label("Levels", systemImage: "slider.horizontal.3")
                    } else {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Levels")
            }

            Button {
                session.sheet = .export
            } label: {
                if usesWideLabels {
                    Label("Export", systemImage: "square.and.arrow.up")
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Export")
            .accessibilityIdentifier("TopExport")

            if !context.usesCompactChrome {
                Button {
                    toggleInspector()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Toggle inspector")
            }
        }
        .padding(.horizontal, context.usesCompactChrome ? 10 : 16)
        .frame(height: context.isShort ? 44 : 56)
        .background(.bar)
    }

    private func importImage() {
        Task {
            if let url = await session.platform.files.pickImage() {
                await session.importImage(at: url)
            }
        }
    }

    private func toggleInspector() {
        if context.shell == .canvasFirst {
            session.inspectorTab = 0
            session.sheet = .inspectorLayers
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                session.showsInspector.toggle()
            }
        }
    }
}

import SwiftUI
import CompositorCore

// MARK: - Shells

/// Bottom bars only: the window is too narrow for a rail, and tall enough to stack controls.
struct CanvasFirstShell: View {
    @ObservedObject var session: PadSession
    let context: LayoutContext

    var body: some View {
        VStack(spacing: 0) {
            PadCanvasView(session: session)
            Divider()
            ToolOptionsBar(session: session, compact: true)
            Divider()
            CompactModeBar(session: session)
        }
    }
}

/// A rail plus a floating inspector: the middle ground, and every short window.
struct RailShell: View {
    @ObservedObject var session: PadSession
    let context: LayoutContext

    var body: some View {
        HStack(spacing: 0) {
            ToolRail(session: session, compact: context.isShort)
            Divider()
            VStack(spacing: 0) {
                ToolOptionsBar(session: session, compact: true)
                Divider()
                ZStack(alignment: .trailing) {
                    PadCanvasView(session: session)
                    if session.showsInspector {
                        InspectorPanel(session: session)
                            .frame(width: context.overlayInspectorWidth)
                            .background(.regularMaterial)
                            .overlay(alignment: .leading) { Divider() }
                            .shadow(color: .black.opacity(0.35), radius: 18, x: -6, y: 0)
                            .transition(.move(edge: .trailing))
                            .zIndex(1)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.showsInspector)
    }
}

/// The widest layout: rail, canvas, and a pinned inspector.
struct StudioShell: View {
    @ObservedObject var session: PadSession
    let context: LayoutContext

    var body: some View {
        HStack(spacing: 0) {
            ToolRail(session: session, compact: false)
            Divider()
            VStack(spacing: 0) {
                ToolOptionsBar(session: session, compact: false)
                Divider()
                PadCanvasView(session: session)
            }
            if session.showsInspector && context.pinsInspector {
                Divider()
                InspectorPanel(session: session)
                    .frame(width: LayoutContext.inspectorWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.showsInspector)
    }
}

// MARK: - Compact mode bar

struct CompactModeBar: View {
    @ObservedObject var session: PadSession

    var body: some View {
        HStack(spacing: 0) {
            item("Tools", "square.grid.2x2") { session.sheet = .tools }
            item("Adjust", "slider.horizontal.3") {
                session.inspectorTab = 1
                session.sheet = .inspectorAdjust
            }
            item("Filters", "camera.filters") {
                session.inspectorTab = 2
                session.sheet = .inspectorFilters
            }
            item("Layers", "square.stack.3d.up") {
                session.inspectorTab = 0
                session.sheet = .inspectorLayers
            }
            item("More", "ellipsis.circle") { session.sheet = .more }
        }
        .frame(height: 54)
        .background(.bar)
    }

    private func item(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("Mode\(title)")
    }
}

// MARK: - Sheets

struct PadSheetView: View {
    @ObservedObject var session: PadSession
    let sheet: PadSheet

    var body: some View {
        switch sheet {
        case .levels:
            LevelsSheet(session: session)
        case .inspectorLayers, .inspectorAdjust, .inspectorFilters:
            inspector
        case .tools:
            ToolGridSheet(session: session)
        case .export:
            ExportSheet(session: session)
        case .text:
            TextSheet(session: session)
        case .more:
            MoreSheet(session: session)
        }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Inspector") { session.sheet = nil }
            InspectorPanel(session: session)
        }
    }
}

struct SheetHeader: View {
    let title: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button("Done", action: dismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("SheetDone")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct ToolGridSheet: View {
    @ObservedObject var session: PadSession

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Tools") { session.sheet = nil }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PadTool.allCases) { tool in
                        Button {
                            session.tool = tool
                            session.platform.haptics.selectionChanged()
                            session.sheet = nil
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: tool.symbol)
                                    .font(.system(size: 22, weight: .medium))
                                Text(tool.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .foregroundStyle(session.tool == tool ? Color.white : Color.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(session.tool == tool
                                        ? Color.accentColor
                                        : Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.title)
                        .accessibilityIdentifier("Tool\(tool.rawValue)")
                        .accessibilityAddTraits(session.tool == tool ? [.isSelected] : [])
                    }
                }
                .padding(16)
            }
        }
    }
}

struct TextSheet: View {
    @ObservedObject var session: PadSession

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Text") { session.sheet = nil }

            VStack(alignment: .leading, spacing: 16) {
                TextField("Text", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($focused)

                Button {
                    session.addTextLayer(text)
                    session.sheet = nil
                } label: {
                    Text("Add text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("AddText")
            }
            .padding(20)

            Spacer()
        }
        .onAppear { focused = true }
    }
}

struct ExportSheet: View {
    @ObservedObject var session: PadSession

    @State private var format: PadExportFormat = .png
    @State private var quality = 0.9
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Export") { session.sheet = nil }

            VStack(alignment: .leading, spacing: 18) {
                Picker("Format", selection: $format) {
                    ForEach(PadExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                if format == .jpeg {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Quality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int((quality * 100).rounded()))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $quality, in: 0.3...1)
                    }
                }

                HStack {
                    Text("Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(session.documentSize.width)) × \(Int(session.documentSize.height))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ExportSize")
                }

                Button {
                    export()
                } label: {
                    HStack(spacing: 8) {
                        if isWorking { ProgressView() }
                        Text(isWorking ? "Exporting…" : "Export")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
                .accessibilityIdentifier("ConfirmExport")

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)

            Spacer()
        }
    }

    private func export() {
        guard #available(iOS 16.0, *) else {
            message = "Export needs iOS 16 or later."
            return
        }
        isWorking = true
        message = nil
        guard let data = session.exportData(format: format, quality: quality) else {
            isWorking = false
            message = "Could not render the document."
            return
        }

        // The share sheet is presented over this sheet, not after dismissing it: a share sheet
        // presented by a sheet that is going away gets torn down with it.
        Task { @MainActor in
            _ = await session.platform.files.save(
                data, suggestedName: "Compositor.\(format.fileExtension)")
            isWorking = false
        }
    }
}

struct MoreSheet: View {
    @ObservedObject var session: PadSession

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "More") { session.sheet = nil }
            VStack(spacing: 10) {
                row("Levels", "slider.horizontal.3") {
                    session.sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak session] in
                        session?.sheet = .levels
                    }
                }
                row("Fit canvas", "arrow.up.left.and.arrow.down.right") {
                    session.sheet = nil
                    session.fit()
                }
                row("Clear strokes", "trash") {
                    session.clearStrokes()
                }
                row("Import from Photos", "photo.on.rectangle") { importFromPhotos() }
                row("Import from Files", "folder") { importImage() }
            }
            .padding(16)
            Spacer()
        }
    }

    private func row(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func importFromPhotos() {
        // The picker presents over this sheet; dismissing the sheet first would take the picker
        // down with it.
        Task { [weak session] in
            guard let session,
                  let files = session.platform.files as? PadFiles,
                  let url = await files.pickImageFromPhotos() else { return }
            session.sheet = nil
            await session.importImage(at: url)
        }
    }

    private func importImage() {
        Task { [weak session] in
            guard let session,
                  let url = await session.platform.files.pickImage() else { return }
            session.sheet = nil
            await session.importImage(at: url)
        }
    }
}

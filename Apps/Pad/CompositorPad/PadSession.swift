import SwiftUI
import UIKit
import Combine
import CompositorCore

enum PadSheet: String, Identifiable {
    case levels
    case tools
    case more
    case export
    case text
    case inspectorLayers
    case inspectorAdjust
    case inspectorFilters

    var id: String { rawValue }
}

enum PadExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"

    var id: String { rawValue }
    var fileExtension: String { self == .png ? "png" : "jpg" }
    var isOpaque: Bool { self == .jpeg }
}

enum PadTool: String, CaseIterable, Identifiable {
    case move, marquee, lasso, wand, crop
    case brush, eraser, clone, smudge, type
    case gradient, eyedropper, hand, zoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: return "Move"
        case .marquee: return "Marquee"
        case .lasso: return "Lasso"
        case .wand: return "Wand"
        case .crop: return "Crop"
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        case .clone: return "Clone"
        case .smudge: return "Smudge"
        case .type: return "Type"
        case .gradient: return "Gradient"
        case .eyedropper: return "Eyedropper"
        case .hand: return "Hand"
        case .zoom: return "Zoom"
        }
    }

    var symbol: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .marquee: return "rectangle.dashed"
        case .lasso: return "lasso"
        case .wand: return "wand.and.stars"
        case .crop: return "crop"
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .clone: return "stamp.fill"
        case .smudge: return "hand.draw.fill"
        case .type: return "textformat"
        case .gradient: return "circle.lefthalf.filled"
        case .eyedropper: return "eyedropper"
        case .hand: return "hand.raised.fill"
        case .zoom: return "magnifyingglass"
        }
    }

    var draws: Bool { self == .brush || self == .eraser }
}

enum LayerBlendMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case darken = "Darken"
    case lighten = "Lighten"
    case difference = "Difference"
    case colorDodge = "Color Dodge"
    case colorBurn = "Color Burn"

    var id: String { rawValue }
}

struct LayerAdjustments: Equatable {
    var exposure = 0.0
    var contrast = 0.0
    var saturation = 0.0
    var temperature = 0.0
    var blur = 0.0
    var mono = false
    var invert = false

    var isIdentity: Bool {
        exposure == 0 && contrast == 0 && saturation == 0 && temperature == 0
            && blur == 0 && !mono && !invert
    }
}

struct PadLevels: Equatable {
    var black = 0.0
    var white = 1.0
    var gamma = 1.0

    var isIdentity: Bool {
        black == 0 && white == 1 && gamma == 1
    }
}

struct PadFilter: Identifiable {
    let id: String
    let name: String
    let adjustments: LayerAdjustments
    let colors: [Color]

    static let all: [PadFilter] = [
        PadFilter(id: "original", name: "Original",
                  adjustments: LayerAdjustments(),
                  colors: [Color(red: 0.25, green: 0.35, blue: 0.55),
                           Color(red: 0.75, green: 0.45, blue: 0.25)]),
        PadFilter(id: "mono", name: "Mono",
                  adjustments: LayerAdjustments(exposure: 0, contrast: 0.15,
                                                saturation: -1, temperature: 0),
                  colors: [Color(white: 0.18), Color(white: 0.72)]),
        PadFilter(id: "vivid", name: "Vivid",
                  adjustments: LayerAdjustments(exposure: 0, contrast: 0.2,
                                                saturation: 0.45, temperature: 0),
                  colors: [Color(red: 0.95, green: 0.25, blue: 0.45),
                           Color(red: 0.2, green: 0.5, blue: 0.95)]),
        PadFilter(id: "warm", name: "Warm",
                  adjustments: LayerAdjustments(exposure: 0.1, contrast: 0,
                                                saturation: 0, temperature: 0.45),
                  colors: [Color(red: 0.95, green: 0.55, blue: 0.2),
                           Color(red: 0.7, green: 0.25, blue: 0.15)]),
        PadFilter(id: "cool", name: "Cool",
                  adjustments: LayerAdjustments(exposure: 0, contrast: 0,
                                                saturation: 0, temperature: -0.45),
                  colors: [Color(red: 0.2, green: 0.45, blue: 0.8),
                           Color(red: 0.15, green: 0.7, blue: 0.75)]),
        PadFilter(id: "fade", name: "Fade",
                  adjustments: LayerAdjustments(exposure: 0.2, contrast: -0.3,
                                                saturation: -0.15, temperature: 0),
                  colors: [Color(red: 0.75, green: 0.7, blue: 0.65),
                           Color(red: 0.45, green: 0.5, blue: 0.55)]),
        PadFilter(id: "noir", name: "Noir",
                  adjustments: LayerAdjustments(exposure: -0.1, contrast: 0.45,
                                                saturation: -1, temperature: 0),
                  colors: [Color(white: 0.05), Color(white: 0.45)]),
        PadFilter(id: "sun", name: "Sun",
                  adjustments: LayerAdjustments(exposure: 0.25, contrast: 0.1,
                                                saturation: 0.1, temperature: 0.25),
                  colors: [Color(red: 1.0, green: 0.8, blue: 0.35),
                           Color(red: 0.9, green: 0.4, blue: 0.2)]),
    ]
}

struct PadLayer: Identifiable {
    enum Kind {
        case gradient(top: Color, bottom: Color)
        case lights
        case text(String)
        case image(UIImage)
        case blank
    }

    let id: UUID
    var name: String
    var isVisible = true
    var opacity: Double = 1
    var blendMode: LayerBlendMode = .normal
    var kind: Kind
    var transform: LayerTransform
    var adjustments = LayerAdjustments()

    var subtitle: String {
        switch kind {
        case .gradient: return "Fill · Gradient"
        case .lights: return "Pixels · Lights"
        case .text(let text): return "Text · \(text)"
        case .image: return "Pixels · Imported"
        case .blank: return "Empty layer"
        }
    }

    var swatch: Color {
        switch kind {
        case .gradient(let top, _): return top
        case .lights: return Color(red: 0.95, green: 0.6, blue: 0.3)
        case .text: return Color(red: 0.97, green: 0.85, blue: 0.6)
        case .image: return Color(white: 0.55)
        case .blank: return Color(white: 0.3)
        }
    }

    static func sampleLayers(documentSize: CGSize) -> [PadLayer] {
        [
            PadLayer(id: UUID(), name: "Background", kind: .gradient(
                top: Color(red: 0.13, green: 0.17, blue: 0.29),
                bottom: Color(red: 0.03, green: 0.04, blue: 0.08)),
                transform: LayerTransform(origin: .zero, size: documentSize)),
            PadLayer(id: UUID(), name: "Lights", kind: .lights,
                transform: LayerTransform(origin: CGPoint(x: 100, y: 80),
                                          size: CGSize(width: 1400, height: 1040))),
            PadLayer(id: UUID(), name: "Title", kind: .text("Compositor"),
                transform: LayerTransform(origin: CGPoint(x: 300, y: 470),
                                          size: CGSize(width: 1000, height: 260), rotation: -6)),
        ]
    }
}

struct PadStroke: Identifiable {
    let id = UUID()
    let layerID: UUID
    var points: [CGPoint]
    var width: CGFloat
    var hardness: Double
    var color: Color
    var erases: Bool
}

private struct PadSnapshot {
    var layers: [PadLayer]
    var strokes: [PadStroke]
    var activeLayerID: UUID
    var levels: PadLevels
    var viewport: CanvasViewport
}

@MainActor
final class PadSession: ObservableObject {
    let platform: PlatformServices

    @Published var viewport = CanvasViewport(documentSize: CGSize(width: 1600, height: 1200))

    @Published var tool: PadTool = .brush {
        didSet { if tool != .crop { cropRect = nil } }
    }

    @Published var brushSize: Double = 56
    @Published var brushHardness: Double = 0.8
    @Published var brushOpacity: Double = 1
    @Published var brushColor = Color(red: 0.98, green: 0.72, blue: 0.36)

    @Published var layers: [PadLayer]
    @Published var activeLayerID: UUID
    @Published var strokes: [PadStroke] = []

    @Published var showsInspector = false
    @Published var sheet: PadSheet?
    @Published var inspectorTab = 0
    @Published var levels = PadLevels()
    @Published var cropRect: CGRect?

    @Published private var undoStack: [PadSnapshot] = []
    @Published private var redoStack: [PadSnapshot] = []
    private var editGroupOpen = false

    init(platform: PlatformServices) {
        self.platform = platform
        let size = CGSize(width: 1600, height: 1200)
        let sample = PadLayer.sampleLayers(documentSize: size)
        layers = sample
        activeLayerID = sample.last!.id
        viewport = CanvasViewport(documentSize: size)
    }

    var documentSize: CGSize { viewport.documentSize }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func layer(_ id: UUID) -> PadLayer? { layers.first { $0.id == id } }

    // MARK: Undo

    private var snapshot: PadSnapshot {
        PadSnapshot(layers: layers, strokes: strokes,
                    activeLayerID: activeLayerID, levels: levels, viewport: viewport)
    }

    /// Sliders call this on touch-down and `endEdit` on touch-up, so a drag is one undo step.
    func beginEdit() {
        guard !editGroupOpen else { return }
        pushUndo()
        editGroupOpen = true
    }

    func endEdit() {
        editGroupOpen = false
    }

    private func pushUndo() {
        guard !editGroupOpen else { return }
        undoStack.append(snapshot)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        restore(previous)
        editGroupOpen = false
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        restore(next)
        editGroupOpen = false
    }

    private func restore(_ snapshot: PadSnapshot) {
        layers = snapshot.layers
        strokes = snapshot.strokes
        activeLayerID = snapshot.activeLayerID
        levels = snapshot.levels
        viewport = snapshot.viewport
    }

    // MARK: Crop

    func applyCrop() {
        guard let crop = cropRect else { return }
        let bounds = CGRect(origin: .zero, size: documentSize)
        let rect = crop.intersection(bounds)
        guard !rect.isNull, rect.width >= 32, rect.height >= 32 else { return }

        pushUndo()
        for index in layers.indices {
            layers[index].transform.origin.x -= rect.minX
            layers[index].transform.origin.y -= rect.minY
        }
        viewport = CanvasViewport(documentSize: rect.size)
        cropRect = nil
        platform.haptics.impact()
    }

    func cancelCrop() {
        cropRect = nil
    }

    func setVisible(_ visible: Bool, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        layers[index].isVisible = visible
    }

    func setOpacity(_ opacity: Double, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].opacity = opacity
    }

    func setBlendMode(_ mode: LayerBlendMode, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }),
              layers[index].blendMode != mode else { return }
        pushUndo()
        layers[index].blendMode = mode
    }

    func adjustments(for id: UUID) -> LayerAdjustments {
        layer(id)?.adjustments ?? LayerAdjustments()
    }

    func setAdjustment(_ keyPath: WritableKeyPath<LayerAdjustments, Double>,
                       value: Double, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].adjustments[keyPath: keyPath] = value
    }

    func setAdjustmentFlag(_ keyPath: WritableKeyPath<LayerAdjustments, Bool>,
                           value: Bool, for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        layers[index].adjustments[keyPath: keyPath] = value
    }

    func resetAdjustments(for id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        layers[index].adjustments = LayerAdjustments()
    }

    func apply(_ filter: PadFilter) {
        guard let index = layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        pushUndo()
        layers[index].adjustments = filter.adjustments
        platform.haptics.selectionChanged()
    }

    // MARK: Layers

    func addBlankLayer() {
        pushUndo()
        let size = CGSize(width: documentSize.width * 0.6, height: documentSize.height * 0.6)
        let origin = CGPoint(x: (documentSize.width - size.width) / 2,
                             y: (documentSize.height - size.height) / 2)
        let layer = PadLayer(id: UUID(), name: "Layer \(layers.count + 1)", kind: .blank,
                             transform: LayerTransform(origin: origin, size: size))
        layers.append(layer)
        activeLayerID = layer.id
    }

    func duplicateActiveLayer() {
        guard let index = layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        pushUndo()
        let source = layers[index]
        var transform = source.transform
        transform.origin.x += 24
        transform.origin.y += 24
        let copy = PadLayer(id: UUID(), name: "\(source.name) copy",
                            isVisible: source.isVisible, opacity: source.opacity,
                            blendMode: source.blendMode,
                            kind: source.kind, transform: transform,
                            adjustments: source.adjustments)
        layers.insert(copy, at: index + 1)
        activeLayerID = copy.id
    }

    func deleteActiveLayer() {
        guard layers.count > 1,
              let index = layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        pushUndo()
        layers.remove(at: index)
        activeLayerID = layers[min(index, layers.count - 1)].id
    }

    func moveActiveLayer(up: Bool) {
        guard let index = layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        let target = up ? index + 1 : index - 1
        guard layers.indices.contains(target) else { return }
        pushUndo()
        layers.swapAt(index, target)
    }

    func clearStrokes() {
        guard !strokes.isEmpty else { return }
        pushUndo()
        strokes.removeAll()
    }

    var activeLayer: PadLayer? { layer(activeLayerID) }

    func setActiveLayerOrigin(_ origin: CGPoint) {
        guard let index = layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        layers[index].transform.origin = origin
    }

    func addGradientLayer(from start: CGPoint, to end: CGPoint, color: Color) {
        pushUndo()
        let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
        let size = CGSize(width: max(40, abs(end.x - start.x)),
                          height: max(40, abs(end.y - start.y)))
        let layer = PadLayer(id: UUID(), name: "Gradient",
                             kind: .gradient(top: color, bottom: color.opacity(0)),
                             transform: LayerTransform(origin: origin, size: size))
        layers.append(layer)
        activeLayerID = layer.id
    }

    func addTextLayer(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pushUndo()
        let size = CGSize(width: documentSize.width * 0.6, height: documentSize.height * 0.22)
        let origin = CGPoint(x: (documentSize.width - size.width) / 2,
                             y: documentSize.height * 0.7 - size.height / 2)
        let layer = PadLayer(id: UUID(), name: trimmed, kind: .text(trimmed),
                             transform: LayerTransform(origin: origin, size: size))
        layers.append(layer)
        activeLayerID = layer.id
    }

    func toggleModifier(_ modifier: ModifierSet) {
        platform.modifiers.toggle(modifier)
        platform.haptics.selectionChanged()
        objectWillChange.send()
    }

    func beginStroke(at point: CGPoint) {
        guard let layer = layer(activeLayerID), layer.isVisible else { return }
        pushUndo()
        let erases = tool == .eraser || platform.modifiers.active.contains(.option)
        strokes.append(PadStroke(layerID: activeLayerID, points: [localPoint(point, in: layer)],
                                 width: CGFloat(brushSize), hardness: brushHardness,
                                 color: brushColor.opacity(brushOpacity),
                                 erases: erases))
    }

    func extendStroke(to point: CGPoint) {
        guard !strokes.isEmpty, let layer = layer(activeLayerID) else { return }
        let index = strokes.count - 1
        let local = localPoint(point, in: layer)
        let modifiers = platform.modifiers.active
        strokes[index].erases = tool == .eraser || modifiers.contains(.option)
        if modifiers.contains(.shift), let start = strokes[index].points.first {
            strokes[index].points = [start, local]
        } else {
            strokes[index].points.append(local)
        }
    }

    /// Strokes live in the layer's own space, so moving the layer carries them along.
    private func localPoint(_ point: CGPoint, in layer: PadLayer) -> CGPoint {
        CGPoint(x: point.x - layer.transform.origin.x,
                y: point.y - layer.transform.origin.y)
    }

    func endStroke() {
        platform.haptics.impact()
    }

    /// Imports a file from disk. RAW is developed by Core Image, everything else downsampled by
    /// ImageIO; either way the decode runs off the main actor because a RAW takes seconds.
    func importImage(at url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let maxDimension = max(documentSize.width, documentSize.height) * 1.2
        let decoded = await Task.detached(priority: .userInitiated) {
            ImageDecoding.decode(contentsOf: url, maxDimension: maxDimension)
        }.value
        guard let decoded else { return }
        addLayer(cgImage: decoded, name: url.deletingPathExtension().lastPathComponent)
    }

    func addLayer(cgImage: CGImage, name: String) {
        pushUndo()
        let pixels = CGSize(width: cgImage.width, height: cgImage.height)
        let limit = CGSize(width: documentSize.width * 0.7, height: documentSize.height * 0.7)
        let ratio = min(limit.width / pixels.width, limit.height / pixels.height, 1)
        let placed = CGSize(width: pixels.width * ratio, height: pixels.height * ratio)
        let origin = CGPoint(x: (documentSize.width - placed.width) / 2,
                             y: (documentSize.height - placed.height) / 2)
        let layer = PadLayer(id: UUID(), name: name, kind: .image(UIImage(cgImage: cgImage)),
                             transform: LayerTransform(origin: origin, size: placed))
        layers.append(layer)
        activeLayerID = layer.id
        platform.haptics.impact()
    }

    /// Imports what is in the app's Documents folder when launched with `-AutoImportDocuments`,
    /// so the simulator can be checked without a drag or a picker.
    func autoImportDocumentsIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-AutoImportDocuments") else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let urls = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil))?
            .filter { Self.importableExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        for url in urls.prefix(3) {
            await importImage(at: url)
        }
    }

    private static let importableExtensions: Set<String> = [
        "arw", "dng", "cr2", "cr3", "nef", "raf", "orf", "rw2", "pef", "srw",
        "jpg", "jpeg", "png", "heic", "tif", "tiff", "webp",
    ]

    func fit() {
        viewport.fit()
    }

    @available(iOS 16.0, *)
    func exportData(format: PadExportFormat, quality: Double) -> Data? {
        let content = PadExportView(session: self)
            .frame(width: documentSize.width, height: documentSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = format.isOpaque
        guard let image = renderer.uiImage else { return nil }
        return format == .png
            ? image.pngData()
            : image.jpegData(compressionQuality: quality)
    }

    @available(iOS 16.0, *)
    func sampleColor(at point: CGPoint) -> Color? {
        let renderer = ImageRenderer(content: PadSampleView(session: self, point: point))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage?.cgImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return Color(.sRGB,
                     red: Double(pixel[0]) / 255,
                     green: Double(pixel[1]) / 255,
                     blue: Double(pixel[2]) / 255,
                     opacity: 1)
    }
}

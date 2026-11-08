import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A command both UIs offer, named once so the Mac's menus and the iOS app's menus agree on when it applies and on the
/// key it answers to. A command specific to one platform's window chrome — the Mac's Hide Others, the iOS app's tab bar
/// — stays with that platform.
nonisolated enum Command: Hashable, Sendable {
    case newCanvas, openProject, openRecentProject, importFiles, save, saveAs
    case exportJPEG, exportPNG, exportAs, closeTab, duplicateProject, renameProject
    case cut, copy, copyMerged, paste, fillForeground, fillBackground, clearSelectionPixels
    case searchCommands, toggleFullscreen, fitCanvas, actualPixels, zoomIn, zoomOut
    case selectAll, deselect, invertSelection, selectLayerPixels, selectSubject, colorRange, selectMaskBlackAreas
    case expandSelection, contractSelection, featherSelection
    case curves, levels, hueSaturation, invertPixels, lastFilter, filter(FilterKind)
    case canvasSize, imageSize, trim, rotateCanvasClockwise, rotateCanvasCounterclockwise
    case flipCanvasHorizontal, flipCanvasVertical
    case newAdjustmentLayer(AdjustmentKind), editAdjustment, transform, layerViaCopy, toggleClipping
    case groupLayers, ungroupLayers, moveOutOfFolder, newBlankLayer, renameLayer, toggleLayerVisibility
    case moveLayerUp, moveLayerDown, mergeLayers, flipLayersHorizontal, flipLayersVertical, deleteLayer
    case gridSettings, loadProofProfile, showAbout, clearRecentProjects, clearGuides
}

/// What a command acts on, gathered by each window from its session and its own chrome. The two platforms fill the same
/// fields, so `CommandCatalog.isEnabled` answers for both.
@MainActor struct CommandContext {
    var session: EditorSession?
    /// A saved project is open, so it can be named, saved and duplicated.
    var hasFile = false
    var hasDocument = false
    var canStartProjectOperation = false
    var changedOnDisk = false
    /// Nothing of the window's own is over the project: no export, no held tab, no dialog.
    var isClear = true
    /// Clear enough to open, close or switch to another project.
    var canSwitch = true
    /// The tab on screen can close: not the only one while it's still empty.
    var canCloseTab = true
    var isTyping = false
    var hasRecentProjects = false
    /// Whether this platform has an editor for the filter or adjustment; the Mac has one for every kind.
    var canEditFilter: (FilterKind) -> Bool = { _ in true }
    /// Whether this platform can make an adjustment layer of the kind at all, editor or not.
    var canAddAdjustment: (AdjustmentKind) -> Bool = { _ in true }
    /// Whether this platform has an editor for the adjustment; one without can be added, not edited.
    var canEditAdjustment: (AdjustmentKind) -> Bool = { _ in true }
    /// A layer copied onto the pasteboard is waiting.
    var canPasteLayers = false

    init(session: EditorSession?) {
        self.session = session
    }
}

/// The key a menu command answers to, named once: the Mac's Keyboard Shortcuts list and the iOS app's menu bar both read
/// it here. The modifier bits are stable ones — Command, Option, Control, Shift — as `ShortcutChord` stores them.
nonisolated struct MenuShortcut: Hashable, Sendable {
    var key: String
    var modifiers: Int
    init(_ key: String, _ modifiers: Int = 1) { self.key = key; self.modifiers = modifiers }
}

extension Command {
    /// The key both UIs give this command, or nil where one gives it none or the two differ: the Mac's ⌘M for Curves,
    /// which iPadOS keeps for Minimize, is the Mac's own.
    var shortcut: MenuShortcut? {
        switch self {
        case .newCanvas: MenuShortcut("n")
        case .openProject: MenuShortcut("o")
        case .save: MenuShortcut("s")
        case .saveAs: MenuShortcut("s", 9)
        case .exportJPEG: MenuShortcut("s", 11)
        case .exportPNG: MenuShortcut("e", 9)
        case .closeTab: MenuShortcut("w")
        case .cut: MenuShortcut("x")
        case .copy: MenuShortcut("c")
        case .copyMerged: MenuShortcut("c", 9)
        case .paste: MenuShortcut("v")
        case .fillForeground: MenuShortcut("\u{7f}", 2)
        case .fillBackground: MenuShortcut("\u{7f}")
        case .filter(.contentAwareFill): MenuShortcut("\u{7f}", 8)
        case .searchCommands: MenuShortcut("f")
        case .fitCanvas: MenuShortcut("0")
        case .actualPixels: MenuShortcut("1")
        case .zoomIn: MenuShortcut("=")
        case .zoomOut: MenuShortcut("-")
        case .selectAll: MenuShortcut("a")
        case .deselect: MenuShortcut("d")
        case .invertSelection: MenuShortcut("i", 9)
        case .selectSubject: MenuShortcut("a", 3)
        case .levels: MenuShortcut("l")
        case .hueSaturation: MenuShortcut("u")
        case .invertPixels: MenuShortcut("i")
        case .canvasSize: MenuShortcut("c", 3)
        case .imageSize: MenuShortcut("i", 3)
        case .transform: MenuShortcut("t")
        case .layerViaCopy: MenuShortcut("j")
        case .toggleClipping: MenuShortcut("g", 3)
        case .groupLayers: MenuShortcut("g")
        case .ungroupLayers: MenuShortcut("g", 9)
        case .newBlankLayer: MenuShortcut("n", 9)
        case .moveLayerUp: MenuShortcut("]")
        case .moveLayerDown: MenuShortcut("[")
        case .mergeLayers: MenuShortcut("e")
        default: nil
        }
    }
}

#if canImport(UIKit)
import UIKit

extension MenuShortcut {
    /// The key as a menu bar takes it: Delete has a name of its own there.
    var uiKey: String { key == "\u{7f}" ? UIKeyCommand.inputDelete : key }
    var uiModifiers: UIKeyModifierFlags {
        var flags: UIKeyModifierFlags = []
        if modifiers & 1 != 0 { flags.insert(.command) }
        if modifiers & 2 != 0 { flags.insert(.alternate) }
        if modifiers & 4 != 0 { flags.insert(.control) }
        if modifiers & 8 != 0 { flags.insert(.shift) }
        return flags
    }
}
#endif

/// When each command applies, in one place: the Mac's `View › …` menu and the iOS app's menu bar both ask here.
@MainActor enum CommandCatalog {
    static func isEnabled(_ command: Command, in context: CommandContext) -> Bool {
        let session = context.session
        switch command {
        case .newCanvas, .openProject, .openRecentProject, .importFiles:
            return context.canSwitch
        case .closeTab:
            return context.canSwitch && context.canCloseTab
        case .save:
            return context.hasFile && context.canStartProjectOperation && !context.changedOnDisk
        // Save As asks where the copy goes, which can't come over what's shown.
        case .saveAs:
            return context.hasFile && context.canStartProjectOperation && !context.changedOnDisk && context.isClear
        case .duplicateProject:
            return context.hasFile && context.canStartProjectOperation && !context.changedOnDisk && context.canSwitch
        case .renameProject:
            return context.hasFile && context.canSwitch
        case .exportJPEG, .exportPNG, .exportAs, .canvasSize, .imageSize, .trim:
            return context.hasDocument && context.canStartProjectOperation && context.isClear
        case .showAbout, .searchCommands:
            return context.isClear
        case .clearRecentProjects:
            return context.hasRecentProjects
        case .fitCanvas, .actualPixels, .zoomIn, .zoomOut, .selectAll, .toggleFullscreen:
            return context.hasDocument
        case .cut:
            return session.map { $0.selection != nil && $0.canCopyPixels } ?? false
        case .copy:
            return session.map { $0.canCopyPixels || $0.canCopyLayer } ?? false
        case .copyMerged:
            return session?.canCopyMerged ?? false
        case .paste:
            return context.canPasteLayers || (session?.canPaste ?? false)
        case .fillForeground, .fillBackground:
            return session?.canEditPixels ?? false
        case .clearSelectionPixels:
            return session.map { $0.selection != nil && $0.canEditPixels } ?? false
        case .deselect, .invertSelection:
            return session.map { $0.selection != nil && $0.canEditSelection } ?? false
        case .selectLayerPixels:
            return session.map { $0.activeLayer?.asset != nil && $0.canEditSelection } ?? false
        case .selectMaskBlackAreas:
            return session.map { $0.activeLayer?.mask != nil && $0.canEditSelection } ?? false
        case .selectSubject:
            return session?.canSelectSubject ?? false
        case .colorRange:
            return (session?.canSelectColorRange ?? false) && context.isClear
        case .expandSelection, .contractSelection, .featherSelection:
            return session?.canModifySelection ?? false
        case .curves, .levels:
            return (session?.canAdjustColors ?? false) && session?.hueSaturation == nil && context.isClear
        case .hueSaturation:
            return (session?.canAdjustColors ?? false) && context.isClear
        case .invertPixels:
            return session?.canInvert ?? false
        case .lastFilter:
            return session?.canRepeatLastFilter ?? false
        case .filter(let kind):
            guard context.isClear, context.canEditFilter(kind) else { return false }
            if kind == .contentAwareFill { return session?.canContentAwareFill ?? false }
            return (kind == .vignette ? session?.canVignette : session?.canAdjustColors) == true && session?.hueSaturation == nil
        case .rotateCanvasClockwise, .rotateCanvasCounterclockwise, .flipCanvasHorizontal, .flipCanvasVertical:
            return session?.canEditLayers ?? false
        case .newAdjustmentLayer(let kind):
            guard context.isClear, context.canAddAdjustment(kind) else { return false }
            return session.map { $0.canEditLayers && $0.document != nil } ?? false
        case .editAdjustment:
            return session.map { session in
                session.canEditLayers && session.activeLayer?.adjustment.map { context.canEditAdjustment($0.kind) } == true
            } == true && context.isClear
        case .transform:
            return session.map { $0.canTransform || $0.canTransformSelection } ?? false
        case .layerViaCopy:
            return session.map { $0.canCopyPixels || ($0.selection == nil && $0.canEditLayers && $0.activeLayer != nil) } ?? false
        case .toggleClipping:
            return session?.canToggleSelectedClipping ?? false
        case .groupLayers, .newBlankLayer:
            return session?.canEditLayers ?? false
        case .ungroupLayers:
            return session?.canUngroupLayers ?? false
        case .moveOutOfFolder:
            return session.map { $0.canEditLayers && $0.activeLayer?.parentID != nil } ?? false
        case .renameLayer:
            return (session.map { $0.canEditLayers && $0.activeLayer != nil } ?? false) && context.isClear
        case .toggleLayerVisibility, .deleteLayer:
            return session.map { $0.canEditLayers && $0.activeLayer != nil } ?? false
        case .moveLayerUp:
            return session?.canMoveActiveLayer(by: 1) ?? false
        case .moveLayerDown:
            return session?.canMoveActiveLayer(by: -1) ?? false
        case .mergeLayers:
            return session?.canMergeLayers ?? false
        case .flipLayersHorizontal, .flipLayersVertical:
            return session?.canTransform ?? false
        case .gridSettings, .loadProofProfile:
            return context.hasDocument && context.isClear
        case .clearGuides:
            return session?.canClearGuides ?? false
        }
    }
}

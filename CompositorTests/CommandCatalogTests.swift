import Testing
@testable import Compositor

/// The Mac's menus and the iOS app's menu bar both ask `CommandCatalog`, so one table here covers both.
@MainActor
struct CommandCatalogTests {
    private func sessionWithLayer() -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 8, height: 8, emptyLayer: true)
        return session
    }

    private func check(_ commands: [Command], _ expected: Bool, in context: CommandContext) {
        for command in commands {
            #expect(CommandCatalog.isEnabled(command, in: context) == expected,
                    "\(command) should be \(expected ? "enabled" : "disabled")")
        }
    }

    @Test func anEmptyWorkspaceOffersProjectCommandsOnly() {
        var context = CommandContext(session: nil)
        context.canSwitch = true
        check([.newCanvas, .openProject, .openRecentProject, .importFiles, .closeTab], true, in: context)
        check([.save, .saveAs, .exportJPEG, .exportPNG, .exportAs, .fitCanvas, .actualPixels, .zoomIn, .zoomOut,
               .selectAll, .cut, .copy, .copyMerged, .paste, .fillForeground, .fillBackground, .curves, .levels,
               .hueSaturation, .invertPixels, .lastFilter, .canvasSize, .imageSize, .trim, .groupLayers,
               .newBlankLayer, .renameLayer, .toggleLayerVisibility, .mergeLayers, .deleteLayer, .transform],
              false, in: context)
    }

    @Test func theOnlyEmptyTabCannotClose() {
        var context = CommandContext(session: nil)
        context.canSwitch = true
        context.canCloseTab = false
        #expect(!CommandCatalog.isEnabled(.closeTab, in: context))
        #expect(CommandCatalog.isEnabled(.newCanvas, in: context))
    }

    @Test func aFileEnablesSavingWithItsProject() {
        var context = CommandContext(session: sessionWithLayer())
        context.hasFile = true
        context.hasDocument = true
        context.canStartProjectOperation = true
        check([.save, .saveAs, .duplicateProject, .renameProject], true, in: context)

        context.changedOnDisk = true
        // Renaming leaves the document alone, so it still applies; writing over the changed file does not.
        check([.save, .saveAs, .duplicateProject], false, in: context)
        check([.renameProject], true, in: context)
    }

    @Test func aDocumentEnablesViewAndImageCommands() {
        let session = EditorSession()
        session.createDocument(width: 8, height: 8)
        var context = CommandContext(session: session)
        context.hasDocument = true
        context.canStartProjectOperation = true
        check([.fitCanvas, .actualPixels, .zoomIn, .zoomOut, .selectAll, .toggleFullscreen, .exportJPEG, .exportPNG,
               .exportAs, .canvasSize, .imageSize, .trim, .rotateCanvasClockwise, .rotateCanvasCounterclockwise,
               .flipCanvasHorizontal, .flipCanvasVertical, .gridSettings, .loadProofProfile,
               .newAdjustmentLayer(.curves), .selectSubject], true, in: context)
        check([.cut, .copy, .copyMerged, .fillForeground, .clearSelectionPixels,
               .selectLayerPixels, .selectMaskBlackAreas, .expandSelection, .contractSelection,
               .featherSelection, .editAdjustment, .transform, .layerViaCopy,
               .toggleClipping, .ungroupLayers, .moveOutOfFolder, .moveLayerUp, .moveLayerDown, .mergeLayers,
               .flipLayersHorizontal, .flipLayersVertical], false, in: context)
    }

    @Test func aLayerEnablesLayerCommands() {
        var context = CommandContext(session: sessionWithLayer())
        context.hasDocument = true
        context.canStartProjectOperation = true
        check([.groupLayers, .newBlankLayer, .renameLayer, .toggleLayerVisibility, .deleteLayer, .layerViaCopy,
               .newAdjustmentLayer(.curves)], true, in: context)
        // One layer has nothing below it to clip or merge with, and no folder around it to leave.
        check([.toggleClipping, .mergeLayers, .moveLayerUp, .moveLayerDown, .ungroupLayers, .moveOutOfFolder],
              false, in: context)
    }

    @Test func anOpenDialogNarrowsWhatApplies() {
        let session = sessionWithLayer()
        var context = CommandContext(session: session)
        context.hasDocument = true
        context.canStartProjectOperation = true
        context.isClear = false
        check([.exportJPEG, .exportPNG, .exportAs, .canvasSize, .imageSize, .trim, .renameLayer, .searchCommands,
               .showAbout, .gridSettings, .loadProofProfile, .colorRange], false, in: context)
        // A layer command that doesn't raise a dialog keeps working beside one.
        check([.groupLayers, .deleteLayer, .toggleLayerVisibility], true, in: context)
    }

    @Test func aPlatformWithoutAnEditorRefusesTheseKinds() {
        var context = CommandContext(session: sessionWithLayer())
        context.hasDocument = true
        context.canStartProjectOperation = true
        context.canEditFilter = { _ in false }
        context.canAddAdjustment = { _ in false }
        context.canEditAdjustment = { _ in false }
        check([.filter(.gaussianBlur), .newAdjustmentLayer(.curves)], false, in: context)

        context.canEditFilter = { $0 != .cameraRaw }
        context.canAddAdjustment = { $0 != .grain }
        context.canEditAdjustment = { $0 != .grain }
        #expect(!CommandCatalog.isEnabled(.filter(.cameraRaw), in: context))
        #expect(!CommandCatalog.isEnabled(.newAdjustmentLayer(.grain), in: context))
        #expect(CommandCatalog.isEnabled(.filter(.gaussianBlur), in: context) == (context.session?.canAdjustColors ?? false))
        #expect(CommandCatalog.isEnabled(.newAdjustmentLayer(.curves), in: context))
    }

    /// The keys both UIs give a command come from the catalog, and the Mac's shortcut list reads the same ones there, so a
    /// new command's key is named once.
    @Test(arguments: [
        (Command.newCanvas, "New Canvas", "n", 1),
        (Command.openProject, "Open Project", "o", 1),
        (Command.save, "Save", "s", 1),
        (Command.saveAs, "Save As", "s", 9),
        (Command.exportJPEG, "Export JPEG", "s", 11),
        (Command.exportPNG, "Export PNG", "e", 9),
        (Command.closeTab, "Close Project", "w", 1),
        (Command.searchCommands, "Search Commands", "f", 1),
        (Command.fitCanvas, "Fit Canvas", "0", 1),
        (Command.actualPixels, "Actual Pixels", "1", 1),
        (Command.zoomIn, "Zoom In", "=", 1),
        (Command.zoomOut, "Zoom Out", "-", 1),
        (Command.cut, "Cut", "x", 1),
        (Command.copy, "Copy", "c", 1),
        (Command.copyMerged, "Copy Merged", "c", 9),
        (Command.paste, "Paste", "v", 1),
        (Command.fillForeground, "Fill with Foreground", "\u{7f}", 2),
        (Command.fillBackground, "Fill with Background", "\u{7f}", 1),
        (Command.filter(.contentAwareFill), "Content-Aware Fill", "\u{7f}", 8),
        (Command.selectAll, "Select All", "a", 1),
        (Command.deselect, "Deselect", "d", 1),
        (Command.invertSelection, "Inverse Selection", "i", 9),
        (Command.selectSubject, "Select Subject", "a", 3),
        (Command.levels, "Levels", "l", 1),
        (Command.hueSaturation, "Hue/Saturation", "u", 1),
        (Command.invertPixels, "Invert Pixels / Mask", "i", 1),
        (Command.canvasSize, "Canvas Size", "c", 3),
        (Command.imageSize, "Image Size", "i", 3),
        (Command.transform, "Transform Layer / Selection", "t", 1),
        (Command.layerViaCopy, "Duplicate / Layer via Copy", "j", 1),
        (Command.toggleClipping, "Toggle Clipping Mask", "g", 3),
        (Command.groupLayers, "Group Layers", "g", 1),
        (Command.ungroupLayers, "Ungroup Layers", "g", 9),
        (Command.newBlankLayer, "New Blank Layer", "n", 9),
        (Command.moveLayerUp, "Move Layer Up", "]", 1),
        (Command.moveLayerDown, "Move Layer Down", "[", 1),
        (Command.mergeLayers, "Merge Layers", "e", 1),
    ])
    func theShortcutListReadsTheCatalog(command: Command, title: String, key: String, modifiers: Int) throws {
        #expect(command.shortcut == MenuShortcut(key, modifiers))
        let definition = try #require(ShortcutDefinition.all.first { $0.title == title && $0.isMenu }, "\(title)")
        #expect(definition.original == ShortcutChord(key, modifiers))
    }

    /// A key only one platform gives a command stays with that platform: iPadOS keeps the Mac's ⌘M, ⌃⌘F and F for itself.
    @Test func aKeyOnlyOnePlatformGivesStaysWithIt() {
        for command in [Command.curves, .lastFilter, .toggleFullscreen, .exportAs, .duplicateProject] {
            #expect(command.shortcut == nil, "\(command)")
        }
    }
}

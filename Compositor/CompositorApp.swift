import SwiftUI
import UniformTypeIdentifiers

@main
struct CompositorApp: App {
    @NSApplicationDelegateAdaptor(CompositorApplicationDelegate.self) private var applicationDelegate
    @AppStorage("navigator.visible") private var showsNavigator = false
    private var session: EditorSession { applicationDelegate.session }
    /// What the menus' commands act on, as the shared catalog asks it.
    private var commandContext: CommandContext {
        var context = CommandContext(session: session)
        context.hasFile = session.document != nil
        context.hasDocument = session.document != nil
        context.canStartProjectOperation = applicationDelegate.projects.canStart
        context.changedOnDisk = session.changedOnDisk
        context.canSwitch = applicationDelegate.projects.canStart
        context.canCloseTab = applicationDelegate.workspace.canClose(applicationDelegate.workspace.current)
        context.hasRecentProjects = !RecentProjects.shared.urls.isEmpty
        context.canPasteLayers = session.copiedLayer != nil
        return context
    }
    private func enabled(_ command: Command) -> Bool { CommandCatalog.isEnabled(command, in: commandContext) }
    private func filterMenuItem(_ kind: FilterKind) -> some View {
        Button(kind.displayName + "…") { session.beginFilter(kind) }
            .disabled(!enabled(.filter(kind)))
    }
    var body: some Scene {
        Window("Compositor", id: "editor") {
            ProjectWorkspaceView(applicationDelegate: applicationDelegate).roundedControls()
        }
            .defaultSize(width: 1180, height: 780)
            // Files opened from Finder or dropped on the Dock icon go to the app delegate, which imports them into
            // the open window. Left to SwiftUI, each one builds a throwaway window and fades the editor out and back.
            .handlesExternalEvents(matching: [])
            // A first launch fills the screen (without going full screen); after that macOS reopens the window at the
            // size it was left.
            .defaultWindowPlacement { _, context in
                WindowPlacement(size: context.defaultDisplay.visibleRect.size)
            }
            // The project's name is already on its tab, so the toolbar doesn't repeat it as a window title.
            .windowToolbarStyle(.unifiedCompact(showsTitle: false))
            .commands {
                CommandGroup(replacing: .undoRedo) {
                    // Dialog text fields keep native text undo; document history
                    // is unavailable while an import or modal edit is active.
                    if session.textDraft != nil || session.levels != nil || session.isProjectBusy || session.showsNewDocument || session.showsImporter || session.renamingLayerID != nil || session.transformEdit?.persistent == true {
                        Button("Undo") {
                            if NSApp.isEditingText {
                                NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil)
                            }
                        }
                            .configuredKeyboardShortcut("z")
                        Button("Redo") {
                            if NSApp.isEditingText {
                                NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil)
                            }
                        }
                            .configuredKeyboardShortcut("z", modifiers: [.command, .shift])
                    } else {
                        // A Save or Open panel's name field undoes its own typing (see `isEditingText`).
                        Button(session.history.canUndo ? String(format: "Undo %@".localized, session.history.undoName.localized) : "Undo".localized) {
                            if NSApp.keyWindow is NSSavePanel { NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil) }
                            else { session.undo() }
                        }
                            .configuredKeyboardShortcut("z").disabled(!session.canUndo)
                        Button(session.history.canRedo ? String(format: "Redo %@".localized, session.history.redoName.localized) : "Redo".localized) {
                            if NSApp.keyWindow is NSSavePanel { NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil) }
                            else { session.redo() }
                        }
                            .configuredKeyboardShortcut("z", modifiers: [.command, .shift]).disabled(!session.canRedo)
                    }
                }
                CommandGroup(replacing: .newItem) {
                    Button("New Canvas…") {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.newCanvas() }
                    }.configuredKeyboardShortcut(.newCanvas)
                        .disabled(!enabled(.newCanvas))
                    Button("Open Project…") {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.open() }
                    }
                        .configuredKeyboardShortcut(.openProject).disabled(!enabled(.openProject))
                    Menu("Open Recent") {
                        ForEach(RecentProjects.shared.urls, id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) {
                                applicationDelegate.showEditor?()
                                Task { await applicationDelegate.projects.open(url) }
                            }
                        }
                        Divider()
                        Button("Clear Menu") { RecentProjects.shared.clear() }
                            .disabled(!enabled(.clearRecentProjects))
                    }
                        .disabled(!enabled(.openRecentProject))
                    Button("Import…") { session.showsImporter = true }
                        .disabled(!enabled(.importFiles))
                }
                CommandGroup(replacing: .saveItem) {
                    Button("Save") { Task { await applicationDelegate.projects.save() } }
                        .configuredKeyboardShortcut(.save).disabled(!enabled(.save))
                    Button("Save As…") { Task { await applicationDelegate.projects.save(asNew: true) } }
                        .configuredKeyboardShortcut(.saveAs)
                        .disabled(!enabled(.saveAs))
                    Divider()
                    // Export As on JPEG.
                    Button("Export JPEG…") { Task { await applicationDelegate.projects.exportAs(start: .jpeg) } }
                        .configuredKeyboardShortcut(.exportJPEG)
                        .disabled(!enabled(.exportJPEG))
                    Button("Export PNG…") { Task { await applicationDelegate.projects.exportPNG() } }
                        .configuredKeyboardShortcut(.exportPNG)
                        .disabled(!enabled(.exportPNG))
                    // Still images or GIF timelines, sized and previewed; ⌥⇧⌘W, as Photoshop's Export As.
                    Button("Export As…") { Task { await applicationDelegate.projects.exportAs() } }
                        .configuredKeyboardShortcut("w", modifiers: [.command, .option, .shift])
                        .disabled(!enabled(.exportAs))
                    Divider()
                    Button("Close Project") {
                        if let window = applicationDelegate.projects.window {
                            Task { await applicationDelegate.projects.close(window) }
                        }
                    }.configuredKeyboardShortcut(.closeTab).disabled(!enabled(.closeTab))
                }
                // Grouped: a commands builder takes at most ten items.
                Group {
                    CommandGroup(after: .appInfo) {
                        #if canImport(Sparkle)
                        Button("Check for Updates…") { applicationDelegate.checkForUpdates() }
                        #endif
                    }
                    CommandGroup(after: .toolbar) {
                        Button("Search Commands…") {
                            CommandPaletteController.shared.toggle(session: session, over: applicationDelegate.projects.window)
                        }
                        .configuredKeyboardShortcut(.searchCommands)
                        // A plain F, shown as menus show keys; the app hands an F meant for a text field to the field
                        // first (see CompositorApplicationDelegate).
                        Toggle("Toggle Fullscreen", isOn: Binding(get: { session.canvasOnly },
                                                            set: { _ in applicationDelegate.toggleCanvasOnly() }))
                            .keyboardShortcut("f", modifiers: [])
                            .disabled(!session.canToggleCanvasOnly)
                        Divider()
                        // With a dialog's preview open (Export As), these zoom that preview rather than the canvas.
                        Button("Fit Canvas") {
                            if let preview = session.previewZoom { preview(.fit) } else { session.fit() }
                        }.configuredKeyboardShortcut(.fitCanvas).disabled(!enabled(.fitCanvas))
                        Button("Actual Pixels") {
                            if let preview = session.previewZoom { preview(.actual) } else { session.zoom(to: 1) }
                        }.configuredKeyboardShortcut(.actualPixels).disabled(!enabled(.actualPixels))
                        Button("Zoom In") {
                            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                            if let preview = session.previewZoom { preview(.zoomIn) } else { session.zoomKeyboard(by: 1) }
                        }
                            .configuredKeyboardShortcut(.zoomIn).disabled(!enabled(.zoomIn))
                        Button("Zoom Out") {
                            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return }
                            if let preview = session.previewZoom { preview(.zoomOut) } else { session.zoomKeyboard(by: -1) }
                        }
                            .configuredKeyboardShortcut(.zoomOut).disabled(!enabled(.zoomOut))
                        Toggle("Navigator (300% and above)", isOn: $showsNavigator)
                        Toggle("Pixel Grid (800% and above)", isOn: Binding(get: { session.showsPixelGrid },
                                                                              set: { session.showsPixelGrid = $0 }))
                            .disabled(!enabled(.viewSwitch(.pixelGrid)))
                        // ⌘H: the Move tool's transform box there; the selection's outline and the guides everywhere else.
                        if session.tool == .move {
                            Toggle("Show Transform Controls", isOn: Binding(get: { session.showsTransformControls },
                                                                              set: { session.showsTransformControls = $0 }))
                                .configuredKeyboardShortcut("h").disabled(!enabled(.viewSwitch(.transformControls)))
                        } else {
                            Toggle("Show Extras", isOn: Binding(get: { session.showsExtras }, set: { session.showsExtras = $0 }))
                                .configuredKeyboardShortcut("h").disabled(session.document == nil)
                        }
                        Divider()
                        // Print: the canvas as the chosen CMYK profile will print it, tucked in a submenu as few need it. No
                        // shortcuts (Photoshop's ⌘Y sits by ⌘U and would be hit by mistake); Search Commands finds them.
                        Menu("CMYK") {
                            Toggle("Proof Colors", isOn: Binding(get: { session.proofsColors }, set: { session.proofsColors = $0 }))
                                .assignableShortcut("CMYK Proof Colors")
                                .disabled(!enabled(.viewSwitch(.proofColors)))
                            Toggle("Gamut Warning", isOn: Binding(get: { session.showsGamutWarning },
                                                                  set: { session.showsGamutWarning = $0 }))
                                .assignableShortcut("CMYK Gamut Warning")
                                .disabled(!enabled(.viewSwitch(.gamutWarning)))
                            Divider()
                            Menu("Profile") {
                                let current = session.proofProfile ?? CMYK.chosen
                                ForEach(CMYK.installed()) { profile in
                                    Toggle(profile.name, isOn: Binding(get: { current?.name == profile.name },
                                                                       set: { if $0 { session.proofProfile = profile } }))
                                }
                                Divider()
                                Button("Load Profile…") { loadCMYKProfile() }
                            }
                        }
                        Group {
                            Divider()
                            Menu("Show") {
                                Toggle("Grid", isOn: Binding(get: { session.showsGrid }, set: { session.showsGrid = $0 }))
                                    .configuredKeyboardShortcut("'").disabled(!enabled(.viewSwitch(.grid)))
                                Toggle("Guides", isOn: Binding(get: { session.showsGuides }, set: { session.showsGuides = $0 }))
                                    .configuredKeyboardShortcut(";").disabled(!enabled(.viewSwitch(.guides)))
                                Toggle("Distances", isOn: Binding(get: { session.showsDistances }, set: { session.showsDistances = $0 }))
                                    .disabled(session.document == nil)
                            }
                            Button("Grid Settings…") { Task { await applicationDelegate.projects.gridSettings() } }
                                .disabled(!enabled(.gridSettings))
                            Toggle("Rulers", isOn: Binding(get: { session.showsRulers }, set: { session.showsRulers = $0 }))
                                .configuredKeyboardShortcut("r").disabled(!enabled(.viewSwitch(.rulers)))
                            Divider()
                            Toggle("Snap", isOn: Binding(get: { session.snapEnabled }, set: { session.snapEnabled = $0 }))
                                .configuredKeyboardShortcut(";", modifiers: [.command, .shift]).disabled(!enabled(.viewSwitch(.snap)))
                            Menu("Snap To") {
                                Toggle("Guides", isOn: Binding(get: { session.snapToGuides }, set: { session.snapToGuides = $0 }))
                                    .disabled(!enabled(.viewSwitch(.snapToGuides)))
                                Toggle("Grid", isOn: Binding(get: { session.snapToGrid }, set: { session.snapToGrid = $0 }))
                                    .disabled(!enabled(.viewSwitch(.snapToGrid)))
                                Toggle("Layers", isOn: Binding(get: { session.snapToLayers }, set: { session.snapToLayers = $0 }))
                                    .disabled(!enabled(.viewSwitch(.snapToLayers)))
                                Toggle("Document Bounds", isOn: Binding(get: { session.snapToDocumentBounds },
                                                                        set: { session.snapToDocumentBounds = $0 }))
                                    .disabled(!enabled(.viewSwitch(.snapToDocumentBounds)))
                            }
                            Divider()
                            Toggle("Lock Guides", isOn: Binding(get: { session.locksGuides }, set: { session.locksGuides = $0 }))
                                .configuredKeyboardShortcut(";", modifiers: [.command, .option]).disabled(!enabled(.viewSwitch(.lockGuides)))
                            Button("Clear Guides") { session.clearGuides() }
                                .disabled(!enabled(.clearGuides))
                        }
                    }
                    // ⌘H toggles the transform controls or extras instead of hiding the app, so Hide keeps its
                    // place in the app menu without the shortcut.
                    CommandGroup(replacing: .appVisibility) {
                        Button("Hide Compositor") { NSApp.hide(nil) }
                        Button("Hide Others") { NSApp.hideOtherApplications(nil) }
                            .configuredKeyboardShortcut("h", modifiers: [.command, .option])
                        Button("Show All") { NSApp.unhideAllApplications(nil) }
                    }
                    // No Services: it acts on selected text and files, which an image editor rarely has.
                    CommandGroup(replacing: .systemServices) {}
                }
                CommandGroup(replacing: .pasteboard) {
                    // Canvas pixels when the canvas has focus; text fields keep their own editing.
                    // Cut, Copy and Paste check when chosen rather than through .disabled: what they depend on
                    // (the pasteboard, the copied pixels, the busy flag) isn't observed, so a disabled state could
                    // go stale — the first Paste after a Copy used to beep until something else refreshed the menu.
                    Button("Cut") {
                        if NSApp.isEditingText { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                        else if session.selection != nil, session.canCopyPixels { Task { await session.cutSelection() } }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut(.cut)
                    Button("Copy") {
                        if NSApp.isEditingText { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                        else if session.canCopyPixels || session.canCopyLayer { session.copySelection() }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut(.copy)
                    Button("Copy Merged") { session.copyMergedSelection() }
                        .configuredKeyboardShortcut(.copyMerged).disabled(!enabled(.copyMerged))
                    Button("Paste") {
                        // On the New canvas screen an image on the clipboard makes the canvas, even with a size field
                        // being typed in; a size copied as text still goes into the field.
                        if session.canPasteImageAsNewCanvas { Task { await session.pasteImageAsNewCanvas() } }
                        else if NSApp.isEditingText { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                        else if applicationDelegate.workspace.pasteCopiedLayer() { }
                        else if session.canPaste { session.paste() }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut(.paste)
                    Button("Paste Into") {
                        if NSApp.isEditingText { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                        else if session.canPasteInto { session.pasteInto() }
                        else { NSSound.beep() }
                    }
                        .configuredKeyboardShortcut(.pasteInto)
                }
                CommandGroup(after: .pasteboard) {
                    Divider()
                    Button("Keyboard Shortcuts…") { ShortcutSettings.shared.show() }
                    // Photoshop's fill shortcuts; in a text field they keep their text meaning.
                    Button("Fill with Foreground Color") {
                        if NSApp.isEditingText {
                            NSApp.sendAction(#selector(NSResponder.deleteWordBackward(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .foreground) } }
                    }
                        .configuredKeyboardShortcut(.fillForeground).disabled(!enabled(.fillForeground))
                    Button("Fill with Background Color") {
                        if NSApp.isEditingText {
                            NSApp.sendAction(#selector(NSResponder.deleteToBeginningOfLine(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .background) } }
                    }
                        .configuredKeyboardShortcut(.fillBackground).disabled(!enabled(.fillBackground))
                    Button("Clear Selection Pixels") { Task { await session.clearSelectedPixels() } }
                        .disabled(!enabled(.clearSelectionPixels))
                    Button("Content-Aware Fill…") { session.beginFilter(.contentAwareFill) }
                        .configuredKeyboardShortcut(.filter(.contentAwareFill)).disabled(!enabled(.filter(.contentAwareFill)))
                }
                CommandMenu("Select") {
                    // A field being edited keeps its own Select All: offer it to the responder chain
                    // first, which covers every kind of text control rather than NSTextView alone,
                    // and select the canvas only when nothing there wanted it.
                    Button("All") {
                        if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) { return }
                        guard session.document != nil else { return }
                        session.selectAll()
                    }
                        // Never disabled: on macOS this menu item is what binds Cmd-A to selectAll:, so
                        // switching it off takes Select All away from every text field too. With no
                        // document and nothing being edited the action simply does nothing.
                        .configuredKeyboardShortcut(.selectAll)
                    Button("Deselect") { session.deselect() }
                        .configuredKeyboardShortcut(.deselect).disabled(!enabled(.deselect))
                    Button("Inverse") { session.invertSelection() }
                        .configuredKeyboardShortcut(.invertSelection)
                        .disabled(!enabled(.invertSelection))
                    Button("Layer's Pixels") {
                        if let id = session.activeLayerID { session.loadLayerSelection(layerID: id) }
                    }
                        .disabled(!enabled(.selectLayerPixels))
                    Button("Subject") { Task { await session.selectSubject() } }
                        .configuredKeyboardShortcut(.selectSubject)
                        .disabled(!enabled(.selectSubject))
                    Button("Color Range…") { session.beginColorRange() }
                        .disabled(!enabled(.colorRange))
                    Button("Mask's Black Areas") {
                        if let id = session.activeLayerID { session.loadMaskSelection(layerID: id) }
                    }
                        .disabled(!enabled(.selectMaskBlackAreas))
                    Divider()
                    Button("Expand…") { session.promptSelectionAmount(.expand) }
                        .disabled(!enabled(.expandSelection))
                    Button("Contract…") { session.promptSelectionAmount(.contract) }
                        .disabled(!enabled(.contractSelection))
                    Button("Border…") { session.promptSelectionAmount(.border) }
                        .disabled(!enabled(.borderSelection))
                    Button("Feather…") { session.promptSelectionAmount(.feather) }
                        .disabled(!enabled(.featherSelection))
                }
                CommandMenu("Image") {
                    Button("Curves…") { session.beginFilter(.curves) }
                        .configuredKeyboardShortcut("m").disabled(!enabled(.curves))
                    Button("Levels…") { session.beginLevels() }
                        .configuredKeyboardShortcut(.levels).disabled(!enabled(.levels))
                    Button("Hue/Saturation…") { session.beginHueSaturation() }
                        .configuredKeyboardShortcut(.hueSaturation).disabled(!enabled(.hueSaturation))
                    ForEach(FilterKind.imageMenuAdjustments, id: \.self) { kind in
                        Button(kind.displayName + "…") { session.beginFilter(kind) }
                            .disabled(!enabled(.filter(kind)))
                    }
                    ForEach(FilterKind.imageMenuCommands, id: \.self) { kind in
                        Button(kind.displayName) { Task { await session.applyFilterNow(kind) } }
                            .disabled(!enabled(.filter(kind)))
                    }
                    Button(session.isMaskSelected ? "Invert Mask".localized : "Invert".localized) { Task { await session.invertPixels() } }
                        .configuredKeyboardShortcut(.invertPixels)
                        .disabled(!enabled(.invertPixels))
                    Divider()
                    Button("Canvas Size…") { Task { await applicationDelegate.projects.canvasSize() } }
                        .configuredKeyboardShortcut(.canvasSize)
                        .disabled(!enabled(.canvasSize))
                    Button("Image Size…") { Task { await applicationDelegate.projects.imageSize() } }
                        .configuredKeyboardShortcut(.imageSize)
                        .disabled(!enabled(.imageSize))
                    Button("Trim…") { Task { await applicationDelegate.projects.trim() } }
                        .disabled(!enabled(.trim))
                    Group {
                        Divider()
                        Button("Rotate Canvas 90° Clockwise") { session.rotateCanvas(clockwise: true) }
                            .disabled(!enabled(.rotateCanvasClockwise))
                        Button("Rotate Canvas 90° Counterclockwise") { session.rotateCanvas(clockwise: false) }
                            .disabled(!enabled(.rotateCanvasCounterclockwise))
                        Button("Flip Canvas Horizontal") { session.flipCanvas(horizontally: true) }
                            .disabled(!enabled(.flipCanvasHorizontal))
                        Button("Flip Canvas Vertical") { session.flipCanvas(horizontally: false) }
                            .disabled(!enabled(.flipCanvasVertical))
                    }
                }
                CommandMenu("Filter") {
                    Button(session.lastFilter.map { String(format: "Last Filter: %@".localized, $0.displayName) } ?? "Last Filter".localized) {
                        Task { await session.repeatLastFilter() }
                    }
                        // ⌃⌘F, as in Photoshop; ⌘F is the command palette.
                        .configuredKeyboardShortcut("f", modifiers: [.command, .control]).disabled(!enabled(.lastFilter))
                    Divider()
                    // Those that can also be adjustment layers, in that menu's order, then the rest.
                    let layered = AdjustmentKind.filters.compactMap(\.filterKind)
                    let others = FilterKind.allCases.filter { $0 != .contentAwareFill && !$0.isImageAdjustment && !layered.contains($0) }
                    ForEach(layered, id: \.self) { filterMenuItem($0) }
                    Divider()
                    ForEach(others, id: \.self) { filterMenuItem($0) }
                }
                CommandMenu("Layer") {
                    Menu("New Adjustment Layer") {
                        // The Image menu's adjustments, then the Filter menu's filters.
                        ForEach(AdjustmentKind.imageAdjustments, id: \.self) { kind in
                            Button(kind.displayName + (kind.isEditable ? "…" : "")) { session.addAdjustment(kind) }
                        }
                        Divider()
                        ForEach(AdjustmentKind.filters, id: \.self) { kind in
                            Button(kind.displayName + "…") { session.addAdjustment(kind) }
                        }
                    }.disabled(!AdjustmentKind.allCases.contains { enabled(.newAdjustmentLayer($0)) })
                    Button("Edit Adjustment…") {
                        session.adjustmentEditingID = session.activeLayerID
                    }.disabled(!enabled(.editAdjustment))
                    Divider()
                    Button(session.canTransformSelection ? "Transform Selection".localized : "Transform Layer".localized) { session.transformCommand() }
                        .configuredKeyboardShortcut(.transform).disabled(!enabled(.transform))
                    Button(session.selection == nil ? "Duplicate Layer".localized : "Layer via Copy".localized) { session.layerViaCopy() }
                        .configuredKeyboardShortcut(.layerViaCopy).disabled(!enabled(.layerViaCopy))
                    Button("Layer via Cut") { Task { await session.layerViaCut() } }
                        .configuredKeyboardShortcut(.layerViaCut).disabled(!enabled(.layerViaCut))
                    Divider()
                    Button(session.selectedClippingTitle) { session.toggleSelectedClipping() }
                    .configuredKeyboardShortcut(.toggleClipping)
                    .disabled(!enabled(.toggleClipping))
                    Divider()
                    Button("Group Selected Layers") { session.groupSelectedLayers() }
                        .configuredKeyboardShortcut(.groupLayers).disabled(!enabled(.groupLayers))
                    Button("Ungroup Layers") { session.ungroupLayers() }
                        .configuredKeyboardShortcut(.ungroupLayers).disabled(!enabled(.ungroupLayers))
                    Button("Move Out of Folder") { session.moveActiveLayerOutOfGroup() }
                        .disabled(!enabled(.moveOutOfFolder))
                    Button("New Blank Layer") { session.addBlankLayer() }
                        .configuredKeyboardShortcut(.newBlankLayer).disabled(!enabled(.newBlankLayer))
                    Button("New Color Fill Layer") { session.addFillLayer() }
                        .disabled(!enabled(.newFillLayer))
                    Button("New Gradient Fill Layer") { session.addGradientFillLayer() }
                        .disabled(!enabled(.newGradientFillLayer))
                    Button("Rename Layer…") { session.renamingLayerID = session.activeLayerID }
                        .disabled(!enabled(.renameLayer))
                    Button(session.visibilityTitle) {
                        session.toggleSelectedLayersVisibility()
                    }.disabled(!enabled(.toggleLayerVisibility))
                    Divider()
                    Button("Move Layer Up") { session.moveActiveLayer(by: 1) }
                        .configuredKeyboardShortcut(.moveLayerUp).disabled(!enabled(.moveLayerUp))
                    Button("Move Layer Down") { session.moveActiveLayer(by: -1) }
                        .configuredKeyboardShortcut(.moveLayerDown).disabled(!enabled(.moveLayerDown))
                    Group {
                        Button(session.mergeTitle) { session.mergeLayers() }
                            .configuredKeyboardShortcut(.mergeLayers).disabled(!enabled(.mergeLayers))
                        Button("Merge Visible") { session.mergeVisibleLayers() }
                            .configuredKeyboardShortcut(.mergeVisibleLayers).disabled(!enabled(.mergeVisibleLayers))
                        Button("Flatten Image") { session.flattenImage() }
                            .disabled(!enabled(.flattenImage))
                        Button("Rasterize Layer") { session.rasterizeLayer() }
                            .disabled(!enabled(.rasterizeLayer))
                        // As in the Layers panel's menu: whichever would change a selected layer, both for a mix.
                        if session.canConvertToSixteenBit || !session.canConvertToEightBit {
                            Button("Convert to 16-Bit") { session.convertLayers(toSixteenBit: true) }
                                .disabled(!session.canConvertToSixteenBit)
                        }
                        if session.canConvertToEightBit {
                            Button("Convert to 8-Bit") { session.convertLayers(toSixteenBit: false) }
                        }
                        Divider()
                        Button("Flip Layer Horizontal") { session.flipLayers(horizontally: true) }
                            .disabled(!enabled(.flipLayersHorizontal))
                        Button("Flip Layer Vertical") { session.flipLayers(horizontally: false) }
                            .disabled(!enabled(.flipLayersVertical))
                        Menu("Align") {
                            ForEach(LayerAlignment.allCases, id: \.self) { alignment in
                                Button(alignment.rawValue.localized) { session.alignLayers(alignment) }
                            }
                        }
                            .disabled(!session.canAlignLayers)
                        Menu("Distribute") {
                            ForEach(LayerDistribution.allCases, id: \.self) { distribution in
                                Button(distribution.rawValue.localized) { session.distributeLayers(distribution) }
                            }
                        }
                            .disabled(!session.canDistributeLayers)
                    }
                    Divider()
                    Button(session.selectedEffect.map { String(format: "Delete %@".localized, $0.kind.displayName) }
                        ?? (session.isMaskSelected && session.activeLayer.flatMap({ session.selectedMask(for: $0) }) != nil ? "Delete Layer Mask".localized
                            : session.selectedLayerIDs.count > 1 ? "Delete Layers".localized : "Delete Layer".localized)) {
                        session.deleteLayerOrMask()
                    }
                        .disabled(!enabled(.deleteLayer))
                }
            }
    }

    /// View › CMYK › Profile › Load Profile: a CMYK ICC profile picked from anywhere, kept and chosen.
    private func loadCMYKProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "icc") ?? .data, UTType(filenameExtension: "icm") ?? .data]
        panel.message = "Choose a CMYK ICC profile, such as the one your printer gave you".localized
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { session.proofProfile = try CMYK.load(url) }
        catch { session.importError = error.localizedDescription }
    }
}

extension NSApplication {
    /// Whether the keyboard is in a text field, so Cut, Copy, Paste, Undo and the fill shortcuts act on its text rather
    /// than the canvas. A Save or Open panel counts: the sandbox runs it in another process, so its file name field
    /// isn't a text view of ours, and copying or pasting a name there reached the canvas instead.
    var isEditingText: Bool { keyWindow?.firstResponder is NSTextView || keyWindow is NSSavePanel }
}

import Testing
import UIKit
@testable import Compositor

/// The menu bar, laid out as the Mac's.
@MainActor @Suite(.serialized) struct MobileMenuBarTests {
    private func shortcut(_ command: UICommand) -> String {
        guard let key = command as? UIKeyCommand, let input = key.input else { return "" }
        let flags = key.modifierFlags
        let name = input == UIKeyCommand.inputDelete ? "⌫" : input.uppercased()
        return (flags.contains(.control) ? "⌃" : "") + (flags.contains(.alternate) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "")
            + (flags.contains(.command) ? "⌘" : "") + name
    }

    /// The app's menus come after View, in the Mac's order.
    @Test func theMenusComeInTheMacsOrder() {
        let bar = MenuBarModel.built(by: AppDelegate())
        #expect(bar.titles == ["Compositor", "File", "Edit", "View", "Select", "Image", "Filter", "Layer", "Window", "Help"])
    }

    /// No shortcut of the app's is one iPadOS keeps for itself, which would never reach it: the Mac's ⌘H and ⌘M go
    /// without on iPad, as Home and Minimize there.
    @Test func noShortcutIsTheSystems() {
        let bar = MenuBarModel.built(by: AppDelegate())
        let keys = bar.bar.commands.compactMap { $0 as? UIKeyCommand } + (EditorWindowController().keyCommands ?? [])
        for key in keys {
            let reserved = MenuBarModel.reserved.first { $0.input == key.input && $0.flags == key.modifierFlags }
            #expect(reserved == nil, "\(key.title) is \(shortcut(key)), which iPadOS keeps for \(reserved?.what ?? "")")
        }
    }

    /// No shortcut the app adds clashes with one already in the system's menus, which UIKit would turn away, and with
    /// it the whole group it came in.
    @Test func noShortcutIsTurnedAway() {
        let bar = MenuBarModel.built(by: AppDelegate())
        #expect(bar.conflicts.isEmpty, "\(bar.conflicts)")
    }

    /// File is the Mac's: New Canvas…, Open Project… and Open Recent in place of the system's Open…, the imports, the
    /// saves, the exports, then Close Tab.
    @Test func theFileMenuIsTheMacs() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let file = try #require(bar.menu(titled: "File"))
        #expect(file.commands.map(\.title) == ["New Canvas…", "Open Project…", "Import Images…", "Import from Photos…", "Save",
                                               "Save As…", "Duplicate", "Rename…", "Export JPEG…", "Export PNG…", "Export As…",
                                               "Close Tab"])
        #expect(file.commands.map(shortcut) == ["⌘N", "⌘O", "", "", "⌘S", "⇧⌘S", "", "", "⌥⇧⌘S", "⇧⌘E", "", "⌘W"])
        #expect(file.submenus.map(\.title) == ["Open Recent"])
    }

    /// Edit holds the Mac's Cut, Copy, Copy Merged and Paste, then the fills; no Find, whose ⌘G, ⇧⌘G and ⌘E the
    /// Layer menu has on the Mac, and no Select All, which is Select › All.
    @Test func editIsTheMacs() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let edit = try #require(bar.menu(titled: "Edit"))
        #expect(edit.commands.map(\.title) == ["Undo", "Redo", "Cut", "Copy", "Copy Merged", "Paste", "Paste Into",
                                               "Fill with Foreground Color",
                                               "Fill with Background Color", "Clear Selection Pixels", "Content-Aware Fill…"])
        #expect(edit.commands.map(shortcut) == ["⌘Z", "⇧⌘Z", "⌘X", "⌘C", "⇧⌘C", "⌘V", "⇧⌘V", "⌥⌫", "⌘⌫", "", "⇧⌫"])
        #expect(!edit.submenus.map(\.title).contains("Find"))
    }

    /// Select › All has ⌘A, as on the Mac, and goes to whichever responds first: a field being edited, or the canvas.
    @Test func selectAllHasCommandA() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let all = try #require(bar.menu(titled: "Select")?.commands.first)
        #expect(all.title == "All" && shortcut(all) == "⌘A")
        #expect(all.action == #selector(UIResponderStandardEditActions.selectAll(_:)))
    }

    /// File's exports are a group of their own, between the saves and Close, as on the Mac, Export As among them.
    @Test func theExportsAreAGroupOfTheirOwn() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let file = try #require(bar.menu(titled: "File"))
        let groups = file.children.compactMap { item -> [String]? in
            guard case .menu(let menu) = item, menu.options.contains(.displayInline) else { return nil }
            return menu.children.compactMap { if case .element(let element) = $0 { element.title } else { nil } }
        }
        #expect(groups.contains(["Save", "Save As…", "Duplicate", "Rename…"]))
        #expect(groups.contains(["Export JPEG…", "Export PNG…", "Export As…"]))
    }

    /// New Canvas… opens a form, as the Mac's does.
    @Test func newCanvasHasAnEllipsis() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        #expect(bar.menu(titled: "File")?.commands.first?.title == "New Canvas…")
    }

    /// No two of the app's shortcuts are the same keys.
    @Test func noTwoShortcutsAreTheSame() {
        let bar = MenuBarModel.built(by: AppDelegate())
        let menuKeys = bar.bar.commands.compactMap { $0 as? UIKeyCommand }
        let windowKeys = EditorWindowController().keyCommands ?? []
        var seen: [String: String] = [:]
        for key in menuKeys + windowKeys {
            guard let input = key.input else { continue }
            let chord = "\(key.modifierFlags.rawValue) \(input)"
            #expect(seen[chord] == nil, "\(key.title) and \(seen[chord] ?? "") are both \(shortcut(key))")
            seen[chord] = key.title
        }
    }

    /// Open Recent ends with Clear Menu, as on the Mac, dimmed when there's nothing to clear.
    @Test func openRecentEndsWithClearMenu() throws {
        let none = AppDelegate.recentItems(for: [])
        #expect(none.count == 1)
        let clear = try #require(none.last as? UICommand)
        #expect(clear.title == "Clear Menu" && clear.attributes.contains(.disabled))
        #expect(clear.action == #selector(EditorWindowController.clearRecentProjects(_:)))

        let project = CompositorDocument.projectsFolder.appending(path: "Harbor.comp")
        let some = AppDelegate.recentItems(for: [project])
        let projects = try #require(some.first as? UIMenu)
        #expect(projects.options.contains(.displayInline))
        #expect(projects.children.map(\.title) == ["Harbor"])
        #expect((some.last as? UICommand)?.title == "Clear Menu" && (some.last as? UICommand)?.attributes.contains(.disabled) == false)
    }

    /// A window with a 200 × 100 project of a gray layer, where every adjustment could be made.
    private func window() throws -> EditorWindowController {
        let controller = EditorWindowController()
        controller.loadViewIfNeeded()
        let session = try #require(controller.activeTab?.session)
        session.createNewProject(width: 200, height: 100)
        let context = try BrushRaster.context(width: 200, height: 100, mask: false)
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let image = try #require(context.makeImage())
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Gray"))
        try #require(session.canAdjustColors)
        return controller
    }

    /// The Mac's adjustments, filters and other commands the iPad has no editor or dialog for yet are listed as on the
    /// Mac, with its titles and shortcuts, dimmed.
    @Test func whatTheIPadCantDoYetIsListedDimmed() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        /// The menu's items in order, those of its inline groups and submenus included.
        func elements(_ menu: MenuBarModel.Menu) -> [UIMenuElement] {
            menu.children.flatMap { item -> [UIMenuElement] in
                switch item {
                case .menu(let menu): elements(menu)
                case .element(let element): [element]
                }
            }
        }
        let image = try #require(bar.menu(titled: "Image"))
        #expect(elements(image).map(\.title) == ["Curves…", "Levels…", "Hue/Saturation…", "Black & White…", "Color Balance…", "Color Lookup…", "Exposure…",
                                                 "Gradient Map…", "Grain…", "Brightness/Contrast…", "Shadows/Highlights…", "Vibrance…",
                                                 "Posterize…", "Threshold…", "Channel Mixer…", "Photo Filter…", "Selective Color…",
                                                 "Replace Color…", "Desaturate", "Auto Tone", "Auto Contrast", "Auto Color", "Equalize",
                                                 "Invert", "Canvas Size…", "Image Size…", "Trim…",
                                                 "Rotate Canvas 90° Clockwise", "Rotate Canvas 90° Counterclockwise",
                                                 "Flip Canvas Horizontal", "Flip Canvas Vertical"])
        let filter = try #require(bar.menu(titled: "Filter"))
        #expect(elements(filter).first?.title == "Last Filter")
        // In the Mac's groups: those that can also be adjustment layers, in that menu's order, then the rest.
        #expect(filter.children.map { item in if case .menu(let group) = item { group.commands.map(\.title) } else { [] } }
                == [["Last Filter"], ["Gaussian Blur…", "Motion Blur…", "Progressive Blur…", "Sharpen…", "Reduce Noise…", "Add Noise…",
                                      "Vignette…", "Bloom / Glow…", "RGB Split…", "Lens Effects…", "Tonal Contrast…"],
                    ["Dither…", "Scanlines…", "Volumetric Light…", "Rim Light…", "Lens Correction…",
                     "Wave…", "Ripple…", "Tilt-Shift Blur…", "Iris Blur…", "Field Blur…", "Spin Blur…", "Path Blur…",
                     "Box Blur…", "Zoom Blur…", "Bokeh Blur…", "Median…", "Photo Effect…", "Mosaic…", "Crystallize…",
                     "Color Halftone…", "Pointillize…", "Hexagonal Pixelate…", "Twirl…", "Pinch…", "Spherize…", "Vortex…",
                     "Hole…", "Circle Splash…", "Torus Lens…", "Gloom…", "Kaleidoscope…", "Find Edges…", "Comic…",
                     "Line Screen…", "Circular Screen…", "Hatched Screen…", "Glass…", "Glass Lozenge…",
                     "Triangle Kaleidoscope…", "False Color…", "Monochrome…", "Disc Blur…", "Lens Flare…", "Light Tunnel…",
                     "Solarize…", "Clouds…", "Difference Clouds…", "Offset…", "Camera Raw Filter…", "Remove Background…"],
                    ["Gaussian Blur", "Motion Blur", "Progressive Blur", "Sharpen", "Reduce Noise", "Add Noise",
                     "Vignette", "Bloom / Glow", "RGB Split", "Lens Effects", "Tonal Contrast"]])
        let fill = try #require(bar.menu(titled: "Edit")?.commands.last)
        // Those with an editor open; the rest are dimmed.
        for command in filter.commands.filter({ ($0.propertyList as? String).flatMap(FilterKind.init) != nil })
            + image.commands.filter({ ["Black & White…", "Color Balance…", "Color Lookup…", "Exposure…", "Gradient Map…", "Grain…",
                                       "Brightness/Contrast…", "Shadows/Highlights…", "Vibrance…", "Posterize…", "Threshold…",
                                       "Channel Mixer…", "Photo Filter…", "Selective Color…", "Replace Color…"].contains($0.title) })
            + [fill] {
            let kind = try #require((command.propertyList as? String).flatMap(FilterKind.init), "\(command.title)")
            // Content-Aware Fill waits for a selection too, which this project hasn't.
            let opens = FilterEditorController.kinds.contains(kind) && kind != .contentAwareFill
            #expect(controller.canPerformAction(command.action, withSender: command) == opens, "\(command.title)")
        }
        let select = try #require(bar.menu(titled: "Select"))
        #expect(Array(elements(select).map(\.title).prefix(7)) == ["All", "Deselect", "Inverse", "Layer’s Pixels", "Subject", "Color Range…",
                                                                  "Mask’s Black Areas"])
        // What has no editor, dialog or window on the iPad yet is a dimmed action, in its place on the Mac.
        func dimmed(_ menu: MenuBarModel.Menu) -> [String] {
            elements(menu).compactMap { ($0 as? UIAction).flatMap { $0.attributes.contains(.disabled) ? $0.title : nil } }
        }
        #expect(dimmed(try #require(bar.menu(titled: "File"))) == [])
        #expect(dimmed(select) == [])
        #expect(dimmed(image) == [])
        #expect(dimmed(filter) == [])
        // The canvas turns and repeats a filter as the Mac's does; Last Filter waits for one to repeat.
        for title in ["Rotate Canvas 90° Clockwise", "Rotate Canvas 90° Counterclockwise"] {
            let command = try #require(image.commands.first { $0.title == title }, "\(title)")
            #expect(controller.canPerformAction(command.action, withSender: command), "\(title)")
        }
        let last = try #require(elements(filter).first as? UICommand)
        #expect(controller.canPerformAction(last.action, withSender: last) == false)
    }

    // MARK: Layer

    /// The Layer menu is the Mac's, with its titles and shortcuts, after the adjustment layers it offers.
    @Test func theLayerMenuIsTheMacs() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let layer = try #require(bar.menu(titled: "Layer"))
        #expect(layer.submenus.map(\.title) == ["New Adjustment Layer"])
        // The Image menu's adjustments, then the Filter menu's filters, as the Mac groups them.
        let adjustments = try #require(layer.submenus.first)
        #expect(adjustments.children.map { item in if case .menu(let group) = item { group.commands.map(\.title) } else { [] } }
                == [AdjustmentKind.imageAdjustments.map { $0.rawValue + ($0.isEditable ? "…" : "") },
                    AdjustmentKind.filters.map { $0.rawValue + "…" }])
        let commands = Array(layer.commands.dropFirst(AdjustmentKind.allCases.count))
        #expect(commands.map(\.title) == ["Edit Adjustment…", "Transform Layer", "Duplicate Layer", "Layer via Cut",
                                          "Create Clipping Mask",
                                          "Group Selected Layers", "Ungroup Layers", "Move Out of Folder", "New Blank Layer",
                                          "New Color Fill Layer", "New Gradient Fill Layer",
                                          "Rename Layer…", "Hide Layer", "Move Layer Up", "Move Layer Down", "Merge Down",
                                          "Merge Visible", "Flatten Image", "Rasterize Layer",
                                          "Flip Layer Horizontal", "Flip Layer Vertical", "Delete Layer"])
        #expect(commands.map(shortcut) == ["", "⌘T", "⌘J", "⇧⌘J", "⌥⌘G", "⌘G", "⇧⌘G", "", "⇧⌘N", "", "", "", "", "⌘]", "⌘[", "⌘E", "", "", "", "", "", ""])
    }

    /// The bar's command titled `title` in the menu titled `menu`.
    private func command(_ title: String, in menu: String, of bar: MenuBarModel) throws -> UICommand {
        try #require(bar.menu(titled: menu)?.commands.first { $0.title == title }, "\(menu) › \(title)")
    }

    /// The title `command` shows now, as the window names it for what it will do.
    private func title(of command: UICommand, in controller: EditorWindowController) throws -> String {
        let shown = try #require(command.copy() as? UICommand)
        controller.validate(shown)
        return shown.title
    }

    /// Whether the window takes `command` now.
    private func takes(_ command: UICommand, in controller: EditorWindowController) -> Bool {
        controller.canPerformAction(command.action, withSender: command)
    }

    /// Chooses `command`, as the menu bar does once the window takes it.
    private func choose(_ command: UICommand, in controller: EditorWindowController) {
        #expect(takes(command, in: controller), "\(command.title)")
        guard takes(command, in: controller) else { return }
        controller.perform(command.action, with: command)
    }

    /// The Layer menu arranges layers as the Mac's does, each command only when it can, and named for what it will do.
    @Test func theLayerMenuArrangesLayers() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        // The new project's empty layer, and the gray one over it.
        let gray = try #require(session.document?.layers.first?.id)
        let top = try #require(session.activeLayerID)
        try #require(session.document?.layers.map(\.id) == [gray, top])

        let up = try command("Move Layer Up", in: "Layer", of: bar)
        let down = try command("Move Layer Down", in: "Layer", of: bar)
        #expect(!takes(up, in: controller))
        choose(down, in: controller)
        #expect(session.document?.layers.map(\.id) == [top, gray])
        #expect(!takes(down, in: controller))
        choose(up, in: controller)
        #expect(session.document?.layers.map(\.id) == [gray, top])

        let clip = try command("Create Clipping Mask", in: "Layer", of: bar)
        #expect(try title(of: clip, in: controller) == "Create Clipping Mask")
        choose(clip, in: controller)
        #expect(session.activeLayer?.maskSourceID == gray)
        #expect(try title(of: clip, in: controller) == "Release Clipping Mask")
        choose(clip, in: controller)
        #expect(session.activeLayer?.maskSourceID == nil)

        let hide = try command("Hide Layer", in: "Layer", of: bar)
        choose(hide, in: controller)
        #expect(session.activeLayer?.isVisible == false)
        #expect(try title(of: hide, in: controller) == "Show Layer")
        choose(hide, in: controller)
        #expect(session.activeLayer?.isVisible == true)

        let merge = try command("Merge Down", in: "Layer", of: bar)
        #expect(try title(of: merge, in: controller) == session.mergeTitle)
        #expect(takes(merge, in: controller) == session.canMergeLayers)

        let blank = try command("New Blank Layer", in: "Layer", of: bar)
        choose(blank, in: controller)
        #expect(session.document?.layers.count == 3)
        #expect(session.activeLayer.map { $0.asset == nil && !$0.isGroup && $0.id != gray && $0.id != top } == true)
    }

    /// Folders, as the Mac's Layer menu makes and undoes them.
    @Test func theLayerMenuGroupsLayers() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        let gray = try #require(session.activeLayerID)
        let layers = session.document?.layers.map(\.id)

        let ungroup = try command("Ungroup Layers", in: "Layer", of: bar)
        let out = try command("Move Out of Folder", in: "Layer", of: bar)
        #expect(!takes(ungroup, in: controller) && !takes(out, in: controller))
        choose(try command("Group Selected Layers", in: "Layer", of: bar), in: controller)
        let folder = try #require(session.activeLayer)
        #expect(folder.isGroup && session.document?.layers.first { $0.id == gray }?.parentID == folder.id)

        session.selectLayers([gray], primary: gray)
        choose(out, in: controller)
        #expect(session.document?.layers.first { $0.id == gray }?.parentID == nil)
        session.selectLayers([folder.id], primary: folder.id)
        choose(ungroup, in: controller)
        #expect(session.document?.layers.map(\.id) == layers)
    }

    /// Delete is named as the Mac's is for what it will delete: the layer, the layers selected, or the mask.
    @Test func deleteIsNamedForWhatItDeletes() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        let delete = try command("Delete Layer", in: "Layer", of: bar)
        let gray = try #require(session.activeLayerID)
        #expect(try title(of: delete, in: controller) == "Delete Layer")

        session.addMask(revealing: true)
        try #require(session.isMaskSelected && session.activeLayer?.mask != nil)
        #expect(try title(of: delete, in: controller) == "Delete Layer Mask")
        choose(delete, in: controller)
        #expect(session.activeLayer?.mask == nil)

        session.selectLayerTarget(gray, mask: false)
        session.addBlankLayer()
        session.selectLayers(Set(session.document?.layers.map(\.id) ?? []), primary: session.activeLayerID)
        #expect(try title(of: delete, in: controller) == "Delete Layers")
        choose(delete, in: controller)
        #expect(session.document?.layers.isEmpty == true)
        #expect(!takes(delete, in: controller))
    }

    /// Flip Layer turns the layer over about its middle; Image › Flip Canvas turns the whole canvas over, about its
    /// middle, so a layer off to one side goes to the other.
    @Test func flipTurnsTheLayerOrTheCanvasOver() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        let index = try #require(session.document?.layers.firstIndex { $0.id == session.activeLayerID })
        session.document?.layers[index].transform.origin = CGPoint(x: 20, y: 10)
        choose(try command("Flip Layer Horizontal", in: "Layer", of: bar), in: controller)
        #expect(session.activeLayer?.transform.flipX == true)
        choose(try command("Flip Layer Vertical", in: "Layer", of: bar), in: controller)
        #expect(session.activeLayer?.transform.flipY == true)
        #expect(session.activeLayer?.transform.origin == CGPoint(x: 20, y: 10))
        choose(try command("Flip Canvas Horizontal", in: "Image", of: bar), in: controller)
        #expect(session.activeLayer?.transform.flipX == false)
        #expect(session.activeLayer?.transform.origin == CGPoint(x: -20, y: 10))
        choose(try command("Flip Canvas Vertical", in: "Image", of: bar), in: controller)
        #expect(session.activeLayer?.transform.flipY == false)
        #expect(session.activeLayer?.transform.origin == CGPoint(x: -20, y: -10))
    }

    /// Rename Layer… asks for the new name in the Layers panel's Rename alert, as the Mac's opens its name for typing.
    @Test func renameLayerAsksForTheName() async throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let controller = try window()
        let window = try await TestHostWindow.show(controller, toolbar: false)
        defer { window.isHidden = true }
        controller.updatePropertiesIfNeeded()
        let session = try #require(controller.activeTab?.session)

        choose(try command("Rename Layer…", in: "Layer", of: bar), in: controller)
        try await TestWait.until(2) { controller.presentedViewController is UIAlertController }
        let alert = try #require(controller.presentedViewController as? UIAlertController)
        #expect(alert.title == "Rename Layer")
        #expect(alert.textFields?.first?.text == "Gray")
        #expect(alert.actions.map(\.title) == ["Cancel", "Rename"])
        // The panel's alert, not the Mac's renaming in place, which would hold the layers.
        #expect(session.renamingLayerID == nil && session.canEditLayers)
        // Another can't come over it.
        #expect(!takes(try command("Rename Layer…", in: "Layer", of: bar), in: controller))
        alert.dismiss(animated: false)
    }

    // MARK: View

    /// The View menu is the Mac's: its zoom commands, its switches, with their shortcuts, Clear Guides, and what the iPad
    /// doesn't do yet, dimmed.
    @Test func theViewMenuIsTheMacs() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let view = try #require(bar.menu(titled: "View"))
        func elements(_ menu: MenuBarModel.Menu) -> [UIMenuElement] {
            menu.children.flatMap { item -> [UIMenuElement] in
                switch item {
                case .menu(let menu): menu.options.contains(.displayInline) ? elements(menu) : [UIMenu(title: menu.title, children: [])]
                case .element(let element): [element]
                }
            }
        }
        #expect(elements(view).map(\.title) == ["Search Commands…", "Toggle Fullscreen", "Fit Canvas", "Actual Pixels", "Zoom In",
                                                "Zoom Out", "Navigator (300% and above)", "Pixel Grid (800% and above)",
                                                "Show Transform Controls", "CMYK", "Show", "Grid Settings…", "Rulers", "Snap", "Snap To",
                                                "Lock Guides", "Clear Guides", "Customize Toolbar…"])
        #expect(view.submenus.map(\.title) == ["CMYK", "Show", "Snap To"])
        #expect(view.submenus[0].submenus.map(\.title) == ["Profile"])
        #expect(view.submenus[1].commands.map(\.title) == ["Grid", "Guides"])
        #expect(view.submenus[2].commands.map(\.title) == ["Guides", "Grid", "Layers", "Document Bounds"])
        #expect(view.commands.map(shortcut) == ["⌘F", "", "⌘0", "⌘1", "⌘=", "⌘-", "", "", "", "", "", "", "⌘'", "⌘;", "",
                                                "⌘R", "⇧⌘;", "", "", "", "", "⌥⌘;", "", ""])
    }

    /// The View menu's switches turn the window's settings on and off, checked when they're on, as on the Mac.
    @Test func theViewSwitchesTurnSettingsOnAndOff() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let view = try #require(bar.menu(titled: "View"))
        let controller = EditorWindowController()
        controller.loadViewIfNeeded()
        let session = try #require(controller.activeTab?.session)
        let switches: [(UICommand, ReferenceWritableKeyPath<EditorSession, Bool>)] = [
            (view.submenus[1].commands[0], \.showsGrid), (view.submenus[1].commands[1], \.showsGuides),
            (try command("Snap", in: "View", of: bar), \.snapEnabled), (view.submenus[2].commands[0], \.snapToGuides),
            (view.submenus[2].commands[1], \.snapToGrid), (view.submenus[2].commands[2], \.snapToLayers),
            (view.submenus[2].commands[3], \.snapToDocumentBounds),
            (try command("Proof Colors", in: "View", of: bar), \.proofsColors),
            (try command("Gamut Warning", in: "View", of: bar), \.showsGamutWarning),
        ]
        // None without a project, as on the Mac.
        #expect(switches.map { takes($0.0, in: controller) } == Array(repeating: false, count: 9))
        session.createNewProject(width: 200, height: 100)
        for (command, setting) in switches {
            let was = session[keyPath: setting]
            let shown = try #require(command.copy() as? UICommand)
            controller.validate(shown)
            #expect(shown.state == (was ? .on : .off), "\(command.title)")
            choose(command, in: controller)
            #expect(session[keyPath: setting] == !was, "\(command.title)")
            controller.validate(shown)
            #expect(shown.state == (was ? .off : .on), "\(command.title)")
        }
    }

    /// Show Transform Controls is the Move tool's, as on the Mac, and its bar's Show Controls follows it.
    @Test func showTransformControlsIsTheMoveTools() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let command = try command("Show Transform Controls", in: "View", of: bar)
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        session.selectTool(.brush)
        #expect(!takes(command, in: controller))
        session.selectTool(.move)
        let options = ToolOptionsBar(frame: CGRect(x: 0, y: 0, width: 1000, height: ToolOptionsBar.height))
        options.session = session
        options.updatePropertiesIfNeeded()
        func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
            view.subviews.flatMap { subview -> [T] in ((subview as? T).map { [$0] } ?? []) + views(type, in: subview) }
        }
        let checkbox = try #require(views(UIButton.self, in: options).first { $0.configuration?.title == "Show Controls" })
        #expect(session.showsTransformControls && checkbox.isSelected)
        choose(command, in: controller)
        options.updatePropertiesIfNeeded()
        #expect(!session.showsTransformControls && !checkbox.isSelected)
    }

    /// Clear Guides takes the project's guides away as one undo step, and only when it has some.
    @Test func clearGuidesTakesTheGuidesAway() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let command = try command("Clear Guides", in: "View", of: bar)
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        #expect(!takes(command, in: controller))
        session.addGuide(CanvasGuide(id: UUID(), axis: .vertical, position: 50))
        choose(command, in: controller)
        #expect(session.document?.guides.isEmpty == true)
        #expect(session.history.undoName == "Clear Guides")
        #expect(!takes(command, in: controller))
    }

    /// Toggle Fullscreen fills the window with the canvas, its menu item checked, and brings the chrome back when chosen
    /// again.
    @Test func toggleFullscreenKeepsOnlyTheCanvas() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let command = try command("Toggle Fullscreen", in: "View", of: bar)
        let controller = try window()
        let session = try #require(controller.activeTab?.session)
        #expect(!session.canvasOnly)
        choose(command, in: controller)
        #expect(session.canvasOnly)
        let shown = try #require(command.copy() as? UICommand)
        controller.validate(shown)
        #expect(shown.state == .on)
        choose(command, in: controller)
        #expect(!session.canvasOnly)
    }

    /// Search Commands holds the bar's menus' commands, and the palette narrows them to what's typed.
    @Test func searchCommandsFindsTheBarsCommands() throws {
        let delegate = AppDelegate()
        let bar = MenuBarModel.built(by: delegate)
        // The registry fills as the bar is built, each command with the menus it sits in.
        let commands = delegate.services.commands.entries
        #expect(commands.contains { $0.title == "Zoom In" && $0.path == "View" })
        #expect(commands.contains { $0.title == "Save" && $0.path == "File" })
        let controller = try window()
        #expect(takes(try command("Search Commands…", in: "View", of: bar), in: controller))
        let palette = CommandPaletteController()
        palette.entries = commands
        palette.loadViewIfNeeded()
        let search = try #require(palette.view.subviews.compactMap { $0 as? UITextField }.first)
        let table = try #require(palette.view.subviews.compactMap { $0 as? UITableView }.first)
        search.text = "new canvas"
        search.sendActions(for: .editingChanged)
        #expect(table.dataSource?.tableView(table, numberOfRowsInSection: 0) == 1)
    }

    /// What the iPad doesn't draw yet — the pixel grid and rulers — and Lock Guides, while guides can't be dragged, are
    /// listed as on the Mac, dimmed, and unchecked, since they do nothing. The rest of the View menu works.
    @Test func whatTheViewCantDoYetIsDimmed() throws {
        let bar = MenuBarModel.built(by: AppDelegate())
        let view = try #require(bar.menu(titled: "View"))
        let controller = try window()
        for command in view.commands where ["Pixel Grid (800% and above)", "Rulers", "Lock Guides"].contains(command.title) {
            #expect(!takes(command, in: controller), "\(command.title)")
            let shown = try #require(command.copy() as? UICommand)
            controller.validate(shown)
            #expect(shown.state == .off, "\(command.title)")
        }
        func elements(_ menu: MenuBarModel.Menu) -> [UIMenuElement] {
            menu.children.flatMap { item -> [UIMenuElement] in
                switch item {
                case .menu(let menu): elements(menu)
                case .element(let element): [element]
                }
            }
        }
        let dimmed = elements(view).compactMap { ($0 as? UIAction).flatMap { $0.attributes.contains(.disabled) ? $0.title : nil } }
        #expect(dimmed == [])
        // Search Commands, fullscreen and CMYK proofing are the Mac's, working from the View menu.
        for title in ["Search Commands…", "Toggle Fullscreen", "Proof Colors", "Gamut Warning", "Load Profile…"] {
            let command = try #require(view.commands.first { $0.title == title }, "\(title)")
            #expect(controller.canPerformAction(command.action, withSender: command), "\(title)")
        }
        // The navigator and grid settings are the Mac's, working from the View menu.
        let navigator = try #require(view.commands.first { $0.title == "Navigator (300% and above)" })
        #expect(controller.canPerformAction(navigator.action, withSender: navigator))
        // Grid Settings opens the Mac's sheet as a dialog.
        let grid = try #require(view.commands.first { $0.title == "Grid Settings…" })
        #expect(controller.canPerformAction(grid.action, withSender: grid))
    }
}

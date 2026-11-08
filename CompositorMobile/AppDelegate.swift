import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// What the app makes once and hands to each window. Read by the menu bar a test builds, which fills its commands.
    let services = MobileServices.shared

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Timing.launched(to: "the app's own code")
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    /// The menu bar, with the Mac's File, Edit, View, Select, Image, Filter and Layer commands, in the Mac's order, and their
    /// shortcuts. The commands go to the window in front (`EditorWindowController`), which enables the ones that apply.
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        services.commands.beginBuild()
        builder.remove(menu: .format)
        // The Mac has no sidebar to show.
        builder.remove(menu: .sidebar)
        // The Mac has no Find: its ⌘G, ⇧⌘G and ⌘E are the Layer menu's.
        builder.remove(menu: .find)
        typealias Window = EditorWindowController
        /// A menu command's key, as the shared catalog names it: the Mac's menus and this one answer to the same keys.
        func keyCommand(_ command: Command, _ title: String, _ action: Selector, _ propertyList: Any? = nil) -> UIKeyCommand {
            let shortcut = command.shortcut ?? MenuShortcut("", 0)
            return UIKeyCommand(title: title.localized, action: action, input: shortcut.uiKey,
                                modifierFlags: shortcut.uiModifiers, propertyList: propertyList)
        }
        // The app menu's About, which iPadOS leaves empty: the app's version, as the Mac's About panel shows it, and its
        // license.
        let aboutCommands: [UIMenuElement] = [UICommand(title: ("About " + AboutController.appName).localized, action: #selector(Window.showAbout(_:)))]
        services.commands.register(aboutCommands, path: "Compositor")
        builder.replaceChildren(ofMenu: .about) { _ in aboutCommands }
        let recent = UIMenu(title: "Open Recent".localized, children: [UIDeferredMenuElement.uncached { completion in
            Task { @MainActor in completion(Self.recentItems(for: self.services.recents.urls)) }
        }])
        let open = UIMenu(options: .displayInline, children: [
            keyCommand(.newCanvas, "New Canvas…", #selector(Window.newCanvasTab(_:))),
            keyCommand(.openProject, "Open Project…", #selector(Window.openProject(_:))),
            recent,
            UICommand(title: "Import Images…".localized, action: #selector(Window.importImages(_:))),
            UICommand(title: "Import from Photos…".localized, action: #selector(Window.importPhotos(_:))),
        ])
        let save = UIMenu(options: .displayInline, children: [
            keyCommand(.save, "Save", #selector(Window.saveProject(_:))),
            keyCommand(.saveAs, "Save As…", #selector(Window.saveProjectAs(_:))),
            UICommand(title: "Duplicate".localized, action: #selector(Window.duplicateProject(_:))),
            UICommand(title: "Rename…".localized, action: #selector(Window.renameProject(_:))),
        ])
        // The exports in a group of their own, in the Mac's order.
        let export = UIMenu(options: .displayInline, children: [
            keyCommand(.exportJPEG, "Export JPEG…", #selector(Window.exportJPEG(_:))),
            keyCommand(.exportPNG, "Export PNG…", #selector(Window.exportPNG(_:))),
            UICommand(title: "Export As…".localized, action: #selector(Window.exportAs(_:))),
        ])
        // In place of the system's Open… and Open Recent, whose ⌘O would otherwise turn ours away.
        for menu in [open, save, export] { services.commands.register(menu.children, path: "File") }
        builder.replace(menu: .open, with: open)
        builder.insertSibling(save, afterMenu: open.identifier)
        builder.insertSibling(export, afterMenu: save.identifier)
        // The Mac's Cut, Copy, Copy Merged and Paste in place of the system's group, then the fills. A field being edited
        // takes Cut, Copy and Paste, and the canvas otherwise; Select All is Select › All.
        let pasteboard = UIMenu.Identifier("com.wonderassembly.compositor.pasteboard")
        let pasteboardMenu = UIMenu(identifier: pasteboard, options: .displayInline, children: [
            keyCommand(.cut, "Cut", #selector(UIResponderStandardEditActions.cut(_:))),
            keyCommand(.copy, "Copy", #selector(UIResponderStandardEditActions.copy(_:))),
            keyCommand(.copyMerged, "Copy Merged", #selector(Window.copyMerged(_:))),
            keyCommand(.paste, "Paste", #selector(UIResponderStandardEditActions.paste(_:))),
            keyCommand(.pasteInto, "Paste Into", #selector(Window.pasteInto(_:))),
        ])
        builder.replace(menu: .standardEdit, with: pasteboardMenu)
        services.commands.register(pasteboardMenu.children, path: "Edit")
        let fills = UIMenu(identifier: UIMenu.Identifier("com.wonderassembly.compositor.fill"), options: .displayInline, children: [
            keyCommand(.fillForeground, "Fill with Foreground Color", #selector(Window.fillWithForeground(_:))),
            keyCommand(.fillBackground, "Fill with Background Color", #selector(Window.fillWithBackground(_:))),
            UICommand(title: "Clear Selection Pixels".localized, action: #selector(Window.clearSelectionPixels(_:))),
            keyCommand(.filter(.contentAwareFill), "Content-Aware Fill…", #selector(Window.applyFilter(_:)), FilterKind.contentAwareFill.rawValue),
        ])
        builder.insertSibling(fills, afterMenu: pasteboard)
        services.commands.register(fills.children, path: "Edit")
        // The Mac's Select, Image, Filter and Layer menus, after View as there. What the iOS app has no editor or dialog for
        // yet is listed, dimmed.
        let select = UIMenu.Identifier("com.wonderassembly.compositor.select")
        let selectElements: [UIMenuElement] = [
            UIMenu(options: .displayInline, children: [
                keyCommand(.selectAll, "All", #selector(UIResponderStandardEditActions.selectAll(_:))),
                keyCommand(.deselect, "Deselect", #selector(Window.deselect(_:))),
                keyCommand(.invertSelection, "Inverse", #selector(Window.invertSelection(_:))),
                UICommand(title: "Layer’s Pixels".localized, action: #selector(Window.selectLayerPixels(_:))),
                keyCommand(.selectSubject, "Subject", #selector(Window.selectSubject(_:))),
                UICommand(title: "Color Range…".localized, action: #selector(Window.colorRange(_:))),
                UICommand(title: "Mask’s Black Areas".localized, action: #selector(Window.selectMaskBlackAreas(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Expand…".localized, action: #selector(Window.expandSelection(_:))),
                UICommand(title: "Contract…".localized, action: #selector(Window.contractSelection(_:))),
                UICommand(title: "Border…".localized, action: #selector(Window.borderSelection(_:))),
                UICommand(title: "Feather…".localized, action: #selector(Window.featherSelection(_:))),
            ]),
        ]
        services.commands.register(selectElements, path: "Select")
        builder.insertSibling(UIMenu(title: "Select".localized, identifier: select, children: selectElements), afterMenu: .view)
        let image = UIMenu.Identifier("com.wonderassembly.compositor.image")
        let imageElements: [UIMenuElement] = [
            // Without the Mac's ⌘M, which iPadOS keeps for Minimize.
            UICommand(title: "Curves…".localized, action: #selector(Window.curves(_:))),
            keyCommand(.levels, "Levels…", #selector(Window.levels(_:))),
            keyCommand(.hueSaturation, "Hue/Saturation…", #selector(Window.hueSaturation(_:))),
        ] + FilterKind.imageMenuAdjustments.map { kind in
            UICommand(title: kind.displayName + "…", action: #selector(Window.applyFilter(_:)), propertyList: kind.rawValue)
        } + FilterKind.imageMenuCommands.map { kind in
            UICommand(title: kind.displayName, action: #selector(Window.applyImageCommand(_:)), propertyList: kind.rawValue)
        } + [
            keyCommand(.invertPixels, "Invert", #selector(Window.invertPixels(_:))),
            UIMenu(options: .displayInline, children: [
                keyCommand(.canvasSize, "Canvas Size…", #selector(Window.canvasSize(_:))),
                keyCommand(.imageSize, "Image Size…", #selector(Window.imageSize(_:))),
                UICommand(title: "Trim…".localized, action: #selector(Window.trim(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Rotate Canvas 90° Clockwise".localized, action: #selector(Window.rotateCanvas(_:)), propertyList: true),
                UICommand(title: "Rotate Canvas 90° Counterclockwise".localized, action: #selector(Window.rotateCanvas(_:)), propertyList: false),
                UICommand(title: "Flip Canvas Horizontal".localized, action: #selector(Window.flipCanvas(_:)), propertyList: true),
                UICommand(title: "Flip Canvas Vertical".localized, action: #selector(Window.flipCanvas(_:)), propertyList: false),
            ]),
        ]
        services.commands.register(imageElements, path: "Image")
        builder.insertSibling(UIMenu(title: "Image".localized, identifier: image, children: imageElements), afterMenu: select)
        let filter = UIMenu.Identifier("com.wonderassembly.compositor.filter")
        // Last Filter first, as on the Mac, dimmed until the iOS app repeats one; the filters it has no editor for yet are
        // dimmed by the window.
        let last: UIMenuElement = UIMenu(options: .displayInline, children: [
            UICommand(title: "Last Filter".localized, action: #selector(Window.repeatLastFilter(_:))),
        ])
        // Those that can also be adjustment layers, in that menu's order, then the rest, as the Mac groups them.
        let layered = AdjustmentKind.filters.compactMap(\.filterKind)
        let others = FilterKind.allCases.filter { $0 != .contentAwareFill && !$0.isImageAdjustment && !layered.contains($0) }
        let filters: [UIMenuElement] = [layered, others].map { group in
            UIMenu(options: .displayInline, children: group.map { kind in
                UICommand(title: kind.displayName + "…", action: #selector(Window.applyFilter(_:)), propertyList: kind.rawValue)
            })
        }
        let filterElements: [UIMenuElement] = [last] + filters + [
            // A filter layer clipped to the layer in hand, as the Mac's Filter menu adds: it changes only that layer.
            UIMenu(title: "Add Smart Filter".localized, children: AdjustmentKind.filters.map { kind in
                UICommand(title: kind.displayName, action: #selector(Window.addSmartFilter(_:)), propertyList: kind.rawValue)
            }),
        ]
        services.commands.register(filterElements, path: "Filter")
        builder.insertSibling(UIMenu(title: "Filter".localized, identifier: filter, children: filterElements), afterMenu: image)
        let layer = UIMenu.Identifier("com.wonderassembly.compositor.layer")
        let layerElements: [UIMenuElement] = [
            // The Image menu's adjustments, then the Filter menu's filters, as on the Mac.
            UIMenu(title: "New Adjustment Layer".localized, children: [AdjustmentKind.imageAdjustments, AdjustmentKind.filters].map { group in
                UIMenu(options: .displayInline, children: group.map { kind in
                    UICommand(title: kind.displayName + (kind.isEditable ? "…" : ""), action: #selector(Window.newAdjustmentLayer(_:)),
                              propertyList: kind.rawValue)
                })
            }),
            UICommand(title: "Edit Adjustment…".localized, action: #selector(Window.editAdjustment(_:))),
            UIMenu(options: .displayInline, children: [
                keyCommand(.transform, "Transform Layer", #selector(Window.transformLayer(_:))),
                keyCommand(.layerViaCopy, "Duplicate Layer", #selector(Window.layerViaCopy(_:))),
                keyCommand(.layerViaCut, "Layer via Cut", #selector(Window.layerViaCut(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                keyCommand(.toggleClipping, "Create Clipping Mask", #selector(Window.toggleClippingMask(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                keyCommand(.groupLayers, "Group Selected Layers", #selector(Window.groupLayers(_:))),
                keyCommand(.ungroupLayers, "Ungroup Layers", #selector(Window.ungroupLayers(_:))),
                UICommand(title: "Move Out of Folder".localized, action: #selector(Window.moveOutOfFolder(_:))),
                keyCommand(.newBlankLayer, "New Blank Layer", #selector(Window.newBlankLayer(_:))),
                UICommand(title: "New Color Fill Layer".localized, action: #selector(Window.newFillLayer(_:))),
                UICommand(title: "New Gradient Fill Layer".localized, action: #selector(Window.newGradientFillLayer(_:))),
                UICommand(title: "Rename Layer…".localized, action: #selector(Window.renameLayer(_:))),
                UICommand(title: "Hide Layer".localized, action: #selector(Window.toggleLayerVisibility(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                keyCommand(.moveLayerUp, "Move Layer Up", #selector(Window.moveLayer(_:)), 1),
                keyCommand(.moveLayerDown, "Move Layer Down", #selector(Window.moveLayer(_:)), -1),
                keyCommand(.mergeLayers, "Merge Down", #selector(Window.mergeLayers(_:))),
                keyCommand(.mergeVisibleLayers, "Merge Visible", #selector(Window.mergeVisibleLayers(_:))),
                UICommand(title: "Flatten Image".localized, action: #selector(Window.flattenImage(_:))),
                UICommand(title: "Rasterize Layer".localized, action: #selector(Window.rasterizeLayer(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Flip Layer Horizontal".localized, action: #selector(Window.flipLayers(_:)), propertyList: true),
                UICommand(title: "Flip Layer Vertical".localized, action: #selector(Window.flipLayers(_:)), propertyList: false),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Delete Layer".localized, action: #selector(Window.deleteLayer(_:))),
            ]),
        ]
        services.commands.register(layerElements, path: "Layer")
        builder.insertSibling(UIMenu(title: "Layer".localized, identifier: layer, children: layerElements), afterMenu: filter)
        let closeElements: [UIMenuElement] = [
            keyCommand(.closeTab, "Close Tab", #selector(Window.closeTab(_:))),
        ]
        services.commands.register(closeElements, path: "File")
        builder.replace(menu: .close, with: UIMenu(options: .displayInline, children: closeElements))
        // The Mac's View menu. The switches it doesn't act on yet are dimmed by the window.
        func toggle(_ title: String, _ viewSwitch: ViewSwitch, _ input: String? = nil,
                    _ flags: UIKeyModifierFlags = .command) -> UICommand {
            if let input {
                return UIKeyCommand(title: title, action: #selector(Window.toggleView(_:)), input: input, modifierFlags: flags,
                                    propertyList: viewSwitch.rawValue)
            }
            return UICommand(title: title, action: #selector(Window.toggleView(_:)), propertyList: viewSwitch.rawValue)
        }
        let viewElements: [UIMenuElement] = [
            UIMenu(options: .displayInline, children: [
                keyCommand(.searchCommands, "Search Commands…", #selector(Window.showCommandPalette(_:))),
                // Without the Mac's F, which a hardware keyboard would take from a field being typed in.
                UICommand(title: "Toggle Fullscreen".localized, action: #selector(Window.toggleFullscreen(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                keyCommand(.fitCanvas, "Fit Canvas", #selector(Window.fitCanvas(_:))),
                keyCommand(.actualPixels, "Actual Pixels", #selector(Window.actualPixels(_:))),
                keyCommand(.zoomIn, "Zoom In", #selector(Window.zoomIn(_:))),
                keyCommand(.zoomOut, "Zoom Out", #selector(Window.zoomOut(_:))),
                UICommand(title: "Navigator (300% and above)".localized, action: #selector(Window.toggleNavigator(_:))),
                toggle("Pixel Grid (800% and above)", .pixelGrid),
                // Without the Mac's ⌘H, which iPadOS keeps for the Home Screen.
                toggle("Show Transform Controls", .transformControls),
            ]),
            // The Mac's CMYK proofing, in its submenu.
            UIMenu(options: .displayInline, children: [
                UIMenu(title: "CMYK".localized, children: [
                    toggle("Proof Colors", .proofColors),
                    toggle("Gamut Warning", .gamutWarning),
                    UIMenu(options: .displayInline, children: [
                        UIMenu(title: "Profile".localized, children: [
                            UIDeferredMenuElement.uncached { completion in
                                Task { @MainActor in completion(Self.cmykProfiles()) }
                            },
                            UICommand(title: "Load Profile…".localized, action: #selector(Window.loadProofProfile(_:))),
                        ]),
                    ]),
                ]),
            ]),
            UIMenu(options: .displayInline, children: [
                UIMenu(title: "Show".localized, children: [toggle("Grid", .grid, "'"), toggle("Guides", .guides, ";")]),
                UICommand(title: "Grid Settings…".localized, action: #selector(Window.gridSettings(_:))),
                toggle("Rulers", .rulers, "r"),
            ]),
            UIMenu(options: .displayInline, children: [
                toggle("Snap", .snap, ";", [.command, .shift]),
                UIMenu(title: "Snap To".localized, children: [
                    toggle("Guides", .snapToGuides), toggle("Grid", .snapToGrid), toggle("Layers", .snapToLayers),
                    toggle("Document Bounds", .snapToDocumentBounds),
                ]),
            ]),
            UIMenu(options: .displayInline, children: [
                toggle("Lock Guides", .lockGuides, ";", [.command, .alternate]),
                UICommand(title: "Clear Guides".localized, action: #selector(Window.clearGuides(_:))),
            ]),
        ]
        services.commands.register(viewElements, path: "View")
#if swift(>=6.2)
        builder.insertElements(viewElements, atStartOfMenu: .view)
#else
        builder.insertChild(UIMenu(options: .displayInline, children: viewElements), atStartOfMenu: .view)
#endif
    }
}

extension AppDelegate {
    /// The CMYK profiles to choose, as View › CMYK › Profile lists them.
    static func cmykProfiles() -> [UIMenuElement] {
        CMYK.installed().map { profile in
            UICommand(title: profile.name, action: #selector(EditorWindowController.chooseProofProfile(_:)),
                      propertyList: profile.name)
        }
    }

    /// Open Recent's items for `urls`, as the Mac's: the projects, newest first, then Clear Menu, dimmed when there are
    /// none.
    static func recentItems(for urls: [URL]) -> [UIMenuElement] {
        let projects: [UIMenuElement] = urls.compactMap { url in
            MobileRecentProjects.reference(to: url).map {
                UICommand(title: url.deletingPathExtension().lastPathComponent,
                          action: #selector(EditorWindowController.openRecentProject(_:)), propertyList: $0)
            }
        }
        let clear = UICommand(title: "Clear Menu".localized, action: #selector(EditorWindowController.clearRecentProjects(_:)),
                              attributes: projects.isEmpty ? .disabled : [])
        return projects.isEmpty ? [clear] : [UIMenu(options: .displayInline, children: projects), clear]
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// What the app made once and hands to this window.
    private let services = MobileServices.shared
    var window: UIWindow?
    /// Whether the app's first window is still to come; its first frame ends the launch.
    private static var launching = true
    private var editor: EditorWindowController? {
        (window?.rootViewController as? UINavigationController)?.viewControllers.first as? EditorWindowController
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let launching = Self.launching
        Self.launching = false
        if launching { Timing.launched(to: "the window") }
        let settingUp = Timing.begin("Window setup")
        // A project or image opened from elsewhere comes into a window already open, as a tab, rather than a new
        // window, as the Mac's does.
        scene.activationConditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
        scene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
        // The canvas keeps room between the tools and the Layers panel, in a window iPadOS may make as small as Split
        // View's. An iPhone's window is its screen, which has no such restriction.
        if UIDevice.current.userInterfaceIdiom == .pad {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 400)
        }
        let editor = EditorWindowController(services: services)
        let window = UIWindow(windowScene: scene)
        // The navigation bar is the window's toolbar; there's nothing to navigate to.
        window.rootViewController = UINavigationController(rootViewController: editor)
        window.makeKeyAndVisible()
        self.window = window
        editor.loadViewIfNeeded()
        if let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity { editor.restore(from: activity) }
        editor.open(connectionOptions.urlContexts.map(\.url))
        Timing.end(settingUp)
        if launching { editor.activeTab?.canvas.afterNextFrame { Timing.launched(to: "the first frame") } }
    }

    /// Files and other apps hand projects and images over here: “Open in Compositor”, or a tap on a project in Files.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        editor?.open(URLContexts.map(\.url))
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? { editor?.restorationActivity }

    /// The switcher or another app taking the keyboard takes the keys' coming up with it.
    func sceneWillResignActive(_ scene: UIScene) { editor?.releaseKeys() }
    func sceneDidEnterBackground(_ scene: UIScene) { editor?.saveAll() }

    func sceneDidDisconnect(_ scene: UIScene) { editor?.closeAll() }
}

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
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
        CommandRegistry.shared.beginBuild()
        builder.remove(menu: .format)
        // The Mac has no sidebar to show.
        builder.remove(menu: .sidebar)
        // The Mac has no Find: its ⌘G, ⇧⌘G and ⌘E are the Layer menu's.
        builder.remove(menu: .find)
        typealias Window = EditorWindowController
        // The app menu's About, which iPadOS leaves empty: the app's version, as the Mac's About panel shows it, and its
        // license.
        let aboutCommands: [UIMenuElement] = [UICommand(title: ("About " + AboutController.appName).localized, action: #selector(Window.showAbout(_:)))]
        CommandRegistry.shared.register(aboutCommands, path: "Compositor")
        builder.replaceChildren(ofMenu: .about) { _ in aboutCommands }
        let recent = UIMenu(title: "Open Recent".localized, children: [UIDeferredMenuElement.uncached { completion in
            Task { @MainActor in completion(Self.recentItems(for: PadRecentProjects.shared.urls)) }
        }])
        let open = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: "New Canvas…".localized, action: #selector(Window.newCanvasTab(_:)), input: "n", modifierFlags: .command),
            UIKeyCommand(title: "Open Project…".localized, action: #selector(Window.openProject(_:)), input: "o", modifierFlags: .command),
            recent,
            UICommand(title: "Import Images…".localized, action: #selector(Window.importImages(_:))),
            UICommand(title: "Import from Photos…".localized, action: #selector(Window.importPhotos(_:))),
        ])
        let save = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: "Save".localized, action: #selector(Window.saveProject(_:)), input: "s", modifierFlags: .command),
            UIKeyCommand(title: "Duplicate".localized, action: #selector(Window.duplicateProject(_:)), input: "s", modifierFlags: [.command, .shift]),
            UICommand(title: "Rename…".localized, action: #selector(Window.renameProject(_:))),
        ])
        // The exports in a group of their own, in the Mac's order.
        let export = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: "Export JPEG…".localized, action: #selector(Window.exportJPEG(_:)), input: "s", modifierFlags: [.command, .alternate, .shift]),
            UIKeyCommand(title: "Export PNG…".localized, action: #selector(Window.exportPNG(_:)), input: "e", modifierFlags: [.command, .shift]),
            UICommand(title: "Export As…".localized, action: #selector(Window.exportAs(_:))),
        ])
        // In place of the system's Open… and Open Recent, whose ⌘O would otherwise turn ours away.
        for menu in [open, save, export] { CommandRegistry.shared.register(menu.children, path: "File") }
        builder.replace(menu: .open, with: open)
        builder.insertSibling(save, afterMenu: open.identifier)
        builder.insertSibling(export, afterMenu: save.identifier)
        // The Mac's Cut, Copy, Copy Merged and Paste in place of the system's group, then the fills. A field being edited
        // takes Cut, Copy and Paste, and the canvas otherwise; Select All is Select › All.
        let pasteboard = UIMenu.Identifier("com.wonderassembly.compositor.pasteboard")
        let pasteboardMenu = UIMenu(identifier: pasteboard, options: .displayInline, children: [
            UIKeyCommand(title: "Cut".localized, action: #selector(UIResponderStandardEditActions.cut(_:)), input: "x", modifierFlags: .command),
            UIKeyCommand(title: "Copy".localized, action: #selector(UIResponderStandardEditActions.copy(_:)), input: "c", modifierFlags: .command),
            UIKeyCommand(title: "Copy Merged".localized, action: #selector(Window.copyMerged(_:)), input: "c", modifierFlags: [.command, .shift]),
            UIKeyCommand(title: "Paste".localized, action: #selector(UIResponderStandardEditActions.paste(_:)), input: "v", modifierFlags: .command),
        ])
        builder.replace(menu: .standardEdit, with: pasteboardMenu)
        CommandRegistry.shared.register(pasteboardMenu.children, path: "Edit")
        let fills = UIMenu(identifier: UIMenu.Identifier("com.wonderassembly.compositor.fill"), options: .displayInline, children: [
            UIKeyCommand(title: "Fill with Foreground Color".localized, action: #selector(Window.fillWithForeground(_:)),
                         input: UIKeyCommand.inputDelete, modifierFlags: .alternate),
            UIKeyCommand(title: "Fill with Background Color".localized, action: #selector(Window.fillWithBackground(_:)),
                         input: UIKeyCommand.inputDelete, modifierFlags: .command),
            UICommand(title: "Clear Selection Pixels".localized, action: #selector(Window.clearSelectionPixels(_:))),
            UIKeyCommand(title: "Content-Aware Fill…".localized, action: #selector(Window.applyFilter(_:)), input: UIKeyCommand.inputDelete,
                         modifierFlags: .shift, propertyList: FilterKind.contentAwareFill.rawValue),
        ])
        builder.insertSibling(fills, afterMenu: pasteboard)
        CommandRegistry.shared.register(fills.children, path: "Edit")
        // The Mac's Select, Image, Filter and Layer menus, after View as there. What the iPad has no editor or dialog for
        // yet is listed, dimmed.
        let select = UIMenu.Identifier("com.wonderassembly.compositor.select")
        let selectElements: [UIMenuElement] = [
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "All".localized, action: #selector(UIResponderStandardEditActions.selectAll(_:)), input: "a", modifierFlags: .command),
                UIKeyCommand(title: "Deselect".localized, action: #selector(Window.deselect(_:)), input: "d", modifierFlags: .command),
                UIKeyCommand(title: "Inverse".localized, action: #selector(Window.invertSelection(_:)), input: "i", modifierFlags: [.command, .shift]),
                UICommand(title: "Layer’s Pixels".localized, action: #selector(Window.selectLayerPixels(_:))),
                UIKeyCommand(title: "Subject".localized, action: #selector(Window.selectSubject(_:)), input: "a", modifierFlags: [.command, .alternate]),
                UICommand(title: "Color Range…".localized, action: #selector(Window.colorRange(_:))),
                UICommand(title: "Mask’s Black Areas".localized, action: #selector(Window.selectMaskBlackAreas(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Expand…".localized, action: #selector(Window.expandSelection(_:))),
                UICommand(title: "Contract…".localized, action: #selector(Window.contractSelection(_:))),
                UICommand(title: "Feather…".localized, action: #selector(Window.featherSelection(_:))),
            ]),
        ]
        CommandRegistry.shared.register(selectElements, path: "Select")
        builder.insertSibling(UIMenu(title: "Select".localized, identifier: select, children: selectElements), afterMenu: .view)
        let image = UIMenu.Identifier("com.wonderassembly.compositor.image")
        let imageElements: [UIMenuElement] = [
            // Without the Mac's ⌘M, which iPadOS keeps for Minimize.
            UICommand(title: "Curves…".localized, action: #selector(Window.curves(_:))),
            UIKeyCommand(title: "Levels…".localized, action: #selector(Window.levels(_:)), input: "l", modifierFlags: .command),
            UIKeyCommand(title: "Hue/Saturation…".localized, action: #selector(Window.hueSaturation(_:)), input: "u", modifierFlags: .command),
        ] + [FilterKind.blackWhite, .colorBalance, .exposure, .gradientMap, .grain].map { kind in
            UICommand(title: kind.displayName + "…", action: #selector(Window.applyFilter(_:)), propertyList: kind.rawValue)
        } + [
            UIKeyCommand(title: "Invert".localized, action: #selector(Window.invertPixels(_:)), input: "i", modifierFlags: .command),
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Canvas Size…".localized, action: #selector(Window.canvasSize(_:)), input: "c", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Image Size…".localized, action: #selector(Window.imageSize(_:)), input: "i", modifierFlags: [.command, .alternate]),
                UICommand(title: "Trim…".localized, action: #selector(Window.trim(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Rotate Canvas 90° Clockwise".localized, action: #selector(Window.rotateCanvas(_:)), propertyList: true),
                UICommand(title: "Rotate Canvas 90° Counterclockwise".localized, action: #selector(Window.rotateCanvas(_:)), propertyList: false),
                UICommand(title: "Flip Canvas Horizontal".localized, action: #selector(Window.flipCanvas(_:)), propertyList: true),
                UICommand(title: "Flip Canvas Vertical".localized, action: #selector(Window.flipCanvas(_:)), propertyList: false),
            ]),
        ]
        CommandRegistry.shared.register(imageElements, path: "Image")
        builder.insertSibling(UIMenu(title: "Image".localized, identifier: image, children: imageElements), afterMenu: select)
        let filter = UIMenu.Identifier("com.wonderassembly.compositor.filter")
        // Last Filter first, as on the Mac, dimmed until the iPad repeats one; the filters it has no editor for yet are
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
        let filterElements: [UIMenuElement] = [last] + filters
        CommandRegistry.shared.register(filterElements, path: "Filter")
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
                UIKeyCommand(title: "Transform Layer".localized, action: #selector(Window.transformLayer(_:)), input: "t", modifierFlags: .command),
                UIKeyCommand(title: "Duplicate Layer".localized, action: #selector(Window.layerViaCopy(_:)), input: "j", modifierFlags: .command),
            ]),
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Create Clipping Mask".localized, action: #selector(Window.toggleClippingMask(_:)), input: "g",
                             modifierFlags: [.command, .alternate]),
            ]),
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Group Selected Layers".localized, action: #selector(Window.groupLayers(_:)), input: "g", modifierFlags: .command),
                UIKeyCommand(title: "Ungroup Layers".localized, action: #selector(Window.ungroupLayers(_:)), input: "g", modifierFlags: [.command, .shift]),
                UICommand(title: "Move Out of Folder".localized, action: #selector(Window.moveOutOfFolder(_:))),
                UIKeyCommand(title: "New Blank Layer".localized, action: #selector(Window.newBlankLayer(_:)), input: "n", modifierFlags: [.command, .shift]),
                UICommand(title: "Rename Layer…".localized, action: #selector(Window.renameLayer(_:))),
                UICommand(title: "Hide Layer".localized, action: #selector(Window.toggleLayerVisibility(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Move Layer Up".localized, action: #selector(Window.moveLayer(_:)), input: "]", modifierFlags: .command,
                             propertyList: 1),
                UIKeyCommand(title: "Move Layer Down".localized, action: #selector(Window.moveLayer(_:)), input: "[", modifierFlags: .command,
                             propertyList: -1),
                UIKeyCommand(title: "Merge Down".localized, action: #selector(Window.mergeLayers(_:)), input: "e", modifierFlags: .command),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Flip Layer Horizontal".localized, action: #selector(Window.flipLayers(_:)), propertyList: true),
                UICommand(title: "Flip Layer Vertical".localized, action: #selector(Window.flipLayers(_:)), propertyList: false),
            ]),
            UIMenu(options: .displayInline, children: [
                UICommand(title: "Delete Layer".localized, action: #selector(Window.deleteLayer(_:))),
            ]),
        ]
        CommandRegistry.shared.register(layerElements, path: "Layer")
        builder.insertSibling(UIMenu(title: "Layer".localized, identifier: layer, children: layerElements), afterMenu: filter)
        let closeElements: [UIMenuElement] = [
            UIKeyCommand(title: "Close Tab".localized, action: #selector(Window.closeTab(_:)), input: "w", modifierFlags: .command),
        ]
        CommandRegistry.shared.register(closeElements, path: "File")
        builder.replace(menu: .close, with: UIMenu(options: .displayInline, children: closeElements))
        // The Mac's View menu. The switches it doesn't act on yet are dimmed by the window.
        func toggle(_ title: String, _ viewSwitch: Window.ViewSwitch, _ input: String? = nil,
                    _ flags: UIKeyModifierFlags = .command) -> UICommand {
            if let input {
                return UIKeyCommand(title: title, action: #selector(Window.toggleView(_:)), input: input, modifierFlags: flags,
                                    propertyList: viewSwitch.rawValue)
            }
            return UICommand(title: title, action: #selector(Window.toggleView(_:)), propertyList: viewSwitch.rawValue)
        }
        let viewElements: [UIMenuElement] = [
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Search Commands…".localized, action: #selector(Window.showCommandPalette(_:)), input: "f", modifierFlags: .command),
                // Without the Mac's F, which a hardware keyboard would take from a field being typed in.
                UICommand(title: "Toggle Fullscreen".localized, action: #selector(Window.toggleFullscreen(_:))),
            ]),
            UIMenu(options: .displayInline, children: [
                UIKeyCommand(title: "Fit Canvas".localized, action: #selector(Window.fitCanvas(_:)), input: "0", modifierFlags: .command),
                UIKeyCommand(title: "Actual Pixels".localized, action: #selector(Window.actualPixels(_:)), input: "1", modifierFlags: .command),
                UIKeyCommand(title: "Zoom In".localized, action: #selector(Window.zoomIn(_:)), input: "=", modifierFlags: .command),
                UIKeyCommand(title: "Zoom Out".localized, action: #selector(Window.zoomOut(_:)), input: "-", modifierFlags: .command),
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
        CommandRegistry.shared.register(viewElements, path: "View")
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
            PadRecentProjects.reference(to: url).map {
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
        let editor = EditorWindowController()
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

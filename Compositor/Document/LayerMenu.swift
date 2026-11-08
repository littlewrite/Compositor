import Foundation

/// A row of a layer's menu. The Mac's right-click menu and the iOS app's long-press menu both build from `LayerMenu`,
/// so a command's title, when it applies, and where a drop puts a layer are written once.
nonisolated enum LayerMenuCommand: Hashable, Sendable {
    case editAdjustment, duplicate, rename, delete
    case toggleClipping, group, ungroup, moveOutOfFolder, merge
    case convertToSixteenBit, convertToEightBit
    case addMask, addMaskRevealAll, addMaskHideAll, toggleMask, deleteMask, toggleMaskLink
    case toggleVisibility, export
}

@MainActor enum LayerMenu {
    /// What a platform's row menu does with a command.
    struct Capabilities {
        /// A pressed effect is what Delete removes, as the iOS app's rows select one.
        var deletesSelectedEffect = false
        var canEditAdjustment: (AdjustmentKind) -> Bool = { _ in true }
    }

    struct Item {
        let command: LayerMenuCommand
        let title: String
        var isEnabled = true
        var isDestructive = false
        /// The Add Mask submenu's rows.
        var children: [Item] = []
    }

    struct Section {
        let items: [Item]
    }

    /// The row menu, top to bottom, in the sections the Mac's separators divide.
    static func sections(in session: EditorSession, capabilities: Capabilities = Capabilities()) -> [Section] {
        let layer = session.activeLayer
        let mask = layer?.mask
        let editable = session.canEditLayers && layer != nil
        var basics: [Item] = []
        if let adjustment = layer?.adjustment {
            basics.append(Item(command: .editAdjustment, title: "Edit Adjustment…".localized,
                               isEnabled: editable && capabilities.canEditAdjustment(adjustment.kind)))
        }
        basics.append(Item(command: .duplicate, title: "Duplicate Layer".localized, isEnabled: editable))
        basics.append(Item(command: .rename, title: "Rename…".localized,
                           isEnabled: editable && session.selectedLayerIDs.count == 1))
        basics.append(Item(command: .delete, title: deleteTitle(in: session, capabilities: capabilities),
                           isEnabled: editable, isDestructive: true))

        var arranging = [
            Item(command: .toggleClipping, title: session.selectedClippingTitle,
                 isEnabled: session.canToggleSelectedClipping),
            Item(command: .group, title: "Group Selected Layers".localized,
                 isEnabled: session.canEditLayers && session.document != nil
                     && (session.document?.layers.count ?? 0) < 10_000 && !session.selectedLayerIDs.isEmpty),
        ]
        if layer?.isGroup == true {
            arranging.append(Item(command: .ungroup, title: "Ungroup Layers".localized, isEnabled: session.canUngroupLayers))
        }
        arranging.append(Item(command: .moveOutOfFolder, title: "Move Out of Folder".localized,
                              isEnabled: session.canEditLayers && layer?.parentID != nil))
        arranging.append(Item(command: .merge, title: session.mergeTitle, isEnabled: session.canMergeLayers))
        // Whichever the selected layers can go to, both for a mix (an HDR layer can go to 16 bits as well as to 8).
        // Shown, greyed, for layers neither applies to.
        let sixteen = session.canConvertToSixteenBit, eight = session.canConvertToEightBit
        if sixteen || !eight {
            arranging.append(Item(command: .convertToSixteenBit, title: "Convert to 16-Bit".localized,
                                  isEnabled: sixteen))
        }
        if eight {
            arranging.append(Item(command: .convertToEightBit, title: "Convert to 8-Bit".localized,
                                  isEnabled: eight))
        }

        let addMaskEnabled = session.canEditMask && mask == nil
        let masks = [
            Item(command: .addMask, title: "Add Mask".localized, isEnabled: addMaskEnabled, children: [
                Item(command: .addMaskRevealAll, title: "Reveal All (White)".localized, isEnabled: addMaskEnabled),
                Item(command: .addMaskHideAll, title: "Hide All (Black)".localized, isEnabled: addMaskEnabled),
            ]),
            Item(command: .toggleMask, title: (mask?.isEnabled == false ? "Enable Mask" : "Disable Mask").localized,
                 isEnabled: session.canEditMask && mask != nil),
            Item(command: .deleteMask, title: "Delete Mask".localized, isEnabled: session.canEditMask && mask != nil),
            Item(command: .toggleMaskLink, title: (mask?.isLinked == false ? "Link Mask" : "Unlink Mask").localized,
                 isEnabled: session.canEditLayers && mask != nil && layer?.isGroup == false && layer?.adjustment == nil),
        ]

        let visibility = [Item(command: .toggleVisibility, title: session.visibilityTitle, isEnabled: editable)]

        var sections = [Section(items: basics), Section(items: arranging), Section(items: masks),
                        Section(items: visibility)]
        let title = (session.selectedLayerIDs.count > 1 ? "Export Layers as PNGs…" : "Export Layer as PNG…").localized
        let canExport = session.canStartProjectOperation && layer != nil && session.exportsLayers != nil
        sections.append(Section(items: [Item(command: .export, title: title, isEnabled: canExport)]))
        return sections
    }

    /// What Delete removes: a pressed effect, the mask, the selected layers, or the active layer.
    static func deleteTitle(in session: EditorSession, capabilities: Capabilities = Capabilities()) -> String {
        if capabilities.deletesSelectedEffect, let effect = session.selectedEffect {
            return String(format: "Delete %@".localized, effect.kind.displayName)
        }
        if session.isMaskSelected, let layer = session.activeLayer, session.selectedMask(for: layer) != nil {
            return "Delete Mask".localized
        }
        return session.selectedLayerIDs.count > 1 ? "Delete Selected Layers".localized : "Delete Layer".localized
    }

    /// When a command applies, for a row menu or for the Mac's menu validation.
    static func isEnabled(_ command: LayerMenuCommand, in session: EditorSession,
                          capabilities: Capabilities = Capabilities()) -> Bool {
        switch command {
        case .editAdjustment:
            guard let adjustment = session.activeLayer?.adjustment else { return false }
            return session.canEditLayers && capabilities.canEditAdjustment(adjustment.kind)
        case .duplicate, .delete, .toggleVisibility:
            return session.canEditLayers && session.activeLayer != nil
        case .rename:
            return session.canEditLayers && session.activeLayer != nil && session.selectedLayerIDs.count == 1
        case .toggleClipping:
            return session.canToggleSelectedClipping
        case .group:
            return session.canEditLayers && session.document != nil
                && (session.document?.layers.count ?? 0) < 10_000 && !session.selectedLayerIDs.isEmpty
        case .ungroup:
            return session.canUngroupLayers
        case .moveOutOfFolder:
            return session.canEditLayers && session.activeLayer?.parentID != nil
        case .merge:
            return session.canMergeLayers
        case .convertToSixteenBit:
            return session.canConvertToSixteenBit
        case .convertToEightBit:
            return session.canConvertToEightBit
        case .addMask, .addMaskRevealAll, .addMaskHideAll:
            return session.canEditMask && session.activeLayer?.mask == nil
        case .toggleMask, .deleteMask:
            return session.canEditMask && session.activeLayer?.mask != nil
        case .toggleMaskLink:
            return session.canEditLayers && session.activeLayer?.mask != nil
                && session.activeLayer?.isGroup == false && session.activeLayer?.adjustment == nil
        case .export:
            return session.canStartProjectOperation && session.activeLayer != nil && session.exportsLayers != nil
        }
    }
}

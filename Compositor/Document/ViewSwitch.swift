import Foundation

/// A switch in the View menu both UIs offer, named once so the Mac's menu and the iOS app's menu bar agree on what it
/// turns on. A switch only one platform has — the Mac's Show Extras and Distances — stays with that platform.
nonisolated enum ViewSwitch: String, CaseIterable, Sendable {
    case pixelGrid, transformControls, grid, guides, rulers, snap, snapToGuides, snapToGrid, snapToLayers,
         snapToDocumentBounds, lockGuides, proofColors, gamutWarning

    var setting: ReferenceWritableKeyPath<EditorSession, Bool> {
        switch self {
        case .pixelGrid: \.showsPixelGrid
        case .transformControls: \.showsTransformControls
        case .grid: \.showsGrid
        case .guides: \.showsGuides
        case .rulers: \.showsRulers
        case .snap: \.snapEnabled
        case .snapToGuides: \.snapToGuides
        case .snapToGrid: \.snapToGrid
        case .snapToLayers: \.snapToLayers
        case .snapToDocumentBounds: \.snapToDocumentBounds
        case .lockGuides: \.locksGuides
        case .proofColors: \.proofsColors
        case .gamutWarning: \.showsGamutWarning
        }
    }
}

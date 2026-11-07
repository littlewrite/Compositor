import UIKit

/// The editor's own colors, dark as the Mac's and light as the system's: they're made from the trait that draws them,
/// so a window follows the appearance it's in.
enum Palette {
    private static func dynamic(_ dark: UIColor, _ light: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    /// Behind the tools, the panels and the settings.
    static let window = dynamic(UIColor(white: 0.14, alpha: 1), UIColor(white: 0.95, alpha: 1))
    /// A card over the canvas, as New canvas's form and a progress card are.
    static let card = dynamic(UIColor(white: 0.18, alpha: 0.96), UIColor(white: 1, alpha: 0.98))
    /// The well a field's or a plot's content sits in.
    static let well = dynamic(UIColor(white: 1, alpha: 0.07), UIColor(white: 0, alpha: 0.05))
    /// What a chosen control is filled with.
    static let selection = dynamic(UIColor(white: 1, alpha: 0.12), UIColor(white: 0, alpha: 0.08))
    /// A line between two parts, or a border around one.
    static let separator = dynamic(UIColor(white: 1, alpha: 0.08), UIColor(white: 0, alpha: 0.12))
    /// A border that shows more than a separator, as around a button or a tab.
    static let border = dynamic(UIColor(white: 1, alpha: 0.14), UIColor(white: 0, alpha: 0.16))
    /// The plot behind a histogram or a curve, and its grid.
    static let plot = dynamic(UIColor(white: 0, alpha: 0.25), UIColor(white: 0, alpha: 0.04))
    static let grid = dynamic(UIColor(white: 1, alpha: 0.12), UIColor(white: 0, alpha: 0.12))
    /// Where the canvas shows no pixels, as around the image and behind a preview.
    static let canvas = dynamic(UIColor(white: 0.105, alpha: 1), UIColor(white: 0.80, alpha: 1))
    /// An image's own backdrop in a dialog, which keeps clear of the sheet around it.
    static let preview = dynamic(UIColor(white: 0.12, alpha: 1), UIColor(white: 0.86, alpha: 1))
    /// What dims the canvas behind what a narrow window brings over it.
    static let dimmed = dynamic(UIColor(white: 0, alpha: 0.35), UIColor(white: 0, alpha: 0.18))
}

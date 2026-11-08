import Foundation

/// The Crop tool's ratio choices, grouped by shape: free and the canvas's own proportions, square, wide, tall. The Mac's
/// Crop bar and the iOS app's list show the same groups.
nonisolated enum CropRatios {
    static let groups = [["Free", "Canvas"], ["1:1"], ["4:3", "16:9", "2.39:1"], ["3:4", "9:16"]]
    static var all: [String] { groups.flatMap { $0 } }
}

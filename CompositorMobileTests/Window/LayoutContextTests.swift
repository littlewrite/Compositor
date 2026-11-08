import Testing
import UIKit
@testable import Compositor

/// The window sizes the mobile design is checked against, measured rather than named: no case asks what device it is.
struct LayoutContextTests {
    @Test func theSkeletonFollowsTheWindow() {
        let cases: [(CGFloat, CGFloat, LayoutContext.Shell, String)] = [
            (320, 568, .canvasFirst, "Stage Manager's narrowest"),
            (390, 844, .canvasFirst, "an iPhone upright"),
            (507, 1024, .canvasFirst, "half of an iPad's Split View"),
            (320, 1024, .canvasFirst, "Slide Over"),
            (568, 320, .rail, "an iPhone on its side: short, not narrow"),
            (744, 1133, .rail, "iPad mini upright: no room beside the canvas"),
            (834, 1194, .studio, "iPad Air upright"),
            (1024, 1366, .studio, "iPad Pro upright"),
            (1194, 700, .studio, "iPad Pro on its side"),
            (1366, 500, .rail, "Stage Manager, wide but short"),
            (744, 500, .rail, "a folded iPad"),
        ]
        for (width, height, shell, what) in cases {
            #expect(LayoutContext(width: width, height: height).shell == shell, "\(what): \(width)×\(height)")
        }
    }

    /// Whatever the window, a pinned inspector leaves the canvas its minimum: that is what makes the threshold a
    /// derivation rather than a number.
    @Test func aStudioWindowLeavesTheCanvasItsMinimum() {
        for width in stride(from: 320.0, through: 1500.0, by: 5) {
            let context = LayoutContext(width: width, height: 900)
            guard context.shell == .studio else { continue }
            let canvas = width - LayoutContext.railWidth - LayoutContext.inspectorWidth
            #expect(canvas >= LayoutContext.minimumCanvas, "\(width) leaves \(canvas)")
        }
    }

    @Test func aShortWindowGivesUpBarsBeforeItGivesUpTheRail() {
        for height in [CGFloat(0), 320, 519] {
            #expect(LayoutContext(width: 1366, height: height).shell == .rail)
            #expect(!LayoutContext(width: 1366, height: height).pinsInspector)
        }
    }

    @Test func onlyAStudioWindowPinsTheInspector() {
        #expect(LayoutContext(width: 1194, height: 834).pinsInspector)
        #expect(!LayoutContext(width: 744, height: 1133).pinsInspector)
        #expect(LayoutContext(width: 744, height: 1133).presentsOverCanvas)
        #expect(LayoutContext(width: 390, height: 844).presentsOverCanvas)
    }
}

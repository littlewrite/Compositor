import CoreGraphics
import Testing
import UIKit
@testable import Compositor

/// A GIF layer's timeline on iPad: the frames above the canvas, the one in view, play, and how long each shows, as the
/// Mac shows them under its canvas.
@MainActor @Suite(.serialized) struct MobileGIFTimelineTests {
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        var found: [T] = []
        if let match = view as? T { found.append(match) }
        for subview in view.subviews { found += views(type, in: subview) }
        return found
    }

    /// The editor, laid out without a window, with a four-frame GIF imported once `importGIF` is true: the strip and
    /// its buttons need no presentation.
    private func shown(importGIF: Bool = true) async throws
        -> (controller: EditorWindowController, session: EditorSession, timeline: GIFTimelineView, gif: URL?) {
        let controller = EditorWindowController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        controller.view.layoutIfNeeded()
        let session = try #require(controller.activeTab?.session)
        var gif: URL?
        if importGIF {
            gif = try MobileGIFFixture.url()
            await session.importImages([gif!])
        }
        controller.updatePropertiesIfNeeded()
        controller.view.layoutIfNeeded()
        let timeline = try #require(views(GIFTimelineView.self, in: controller.view).first)
        timeline.updatePropertiesIfNeeded()
        timeline.layoutIfNeeded()
        return (controller, session, timeline, gif)
    }

    /// The strip is there for a GIF layer, taking room above the canvas, and gone while there is none.
    @Test func theTimelineIsShownForAGIFLayer() async throws {
        let (controller, session, timeline, gif) = try await shown(importGIF: false)
        defer { if let gif { try? FileManager.default.removeItem(at: gif) } }
        #expect(timeline.isHidden)
        #expect(timeline.bounds.height == 0)

        let url = try MobileGIFFixture.url()
        defer { try? FileManager.default.removeItem(at: url) }
        await session.importImages([url])
        controller.updatePropertiesIfNeeded()
        controller.view.layoutIfNeeded()
        timeline.updatePropertiesIfNeeded()
        timeline.layoutIfNeeded()

        #expect(session.gifTimelineLayerID != nil)
        #expect(!timeline.isHidden)
        #expect(timeline.bounds.height == GIFTimelineView.height)
        let list = try #require(views(UICollectionView.self, in: timeline).first)
        #expect(list.numberOfItems(inSection: 0) == 4)
        #expect(views(UILabel.self, in: timeline).contains { $0.text == "1/4" })
    }

    /// Tapping a frame shows it, as clicking one on the Mac does.
    @Test func aFrameTapShowsThatFrame() async throws {
        let (_, session, timeline, gif) = try await shown()
        defer { if let gif { try? FileManager.default.removeItem(at: gif) } }
        let list = try #require(views(UICollectionView.self, in: timeline).first)
        timeline.collectionView(list, didSelectItemAt: IndexPath(item: 1, section: 0))
        try await TestWait.until(5) { session.gifTimelineSelectedFrameIndex == 1 }
        timeline.updatePropertiesIfNeeded()
        #expect(views(UILabel.self, in: timeline).contains { $0.text == "2/4" })
    }

    /// Play runs the frames on and pause stops them, from the one in view.
    @Test func playRunsTheFrames() async throws {
        let (_, session, timeline, gif) = try await shown()
        defer { if let gif { try? FileManager.default.removeItem(at: gif) } }
        let play = try #require(views(UIButton.self, in: timeline).first { $0.accessibilityLabel == "Play" })
        play.sendActions(for: .primaryActionTriggered)
        timeline.updatePropertiesIfNeeded()
        #expect(session.gifTimelineIsPlaying)
        play.sendActions(for: .primaryActionTriggered)
        timeline.updatePropertiesIfNeeded()
        #expect(!session.gifTimelineIsPlaying)
    }

    /// The timing menu gives every frame the delay chosen, or the GIF's own again.
    @Test func theMenuSetsTheFramesDelay() async throws {
        let (_, session, timeline, gif) = try await shown()
        defer { if let gif { try? FileManager.default.removeItem(at: gif) } }
        let timing = try #require(views(UIButton.self, in: timeline).first { $0.accessibilityLabel == "How long each frame shows" })
        func items(_ menu: UIMenu?) -> [UIMenuElement] {
            (menu?.children ?? []).flatMap { ($0 as? UIMenu)?.children ?? [$0] }
        }
        let hundred = try #require(items(timing.menu).compactMap { $0 as? UIAction }.first { $0.title.hasPrefix("100 ms") })
        hundred.performWithSender(nil, target: nil)
        timeline.updatePropertiesIfNeeded()
        #expect(session.gifTimelineTiming.mode == .uniform)
        #expect(abs(session.gifTimelineTiming.uniformDelay - 0.1) < 0.0001)

        let original = try #require(items(timing.menu).compactMap { $0 as? UIAction }.first { $0.title.hasPrefix("Original") })
        original.performWithSender(nil, target: nil)
        timeline.updatePropertiesIfNeeded()
        #expect(session.gifTimelineTiming.mode == .perFrame)
        // The GIF's own delays: 40, 160, 80 and 240 ms.
        #expect(items(timing.menu).contains { $0.title == "Original · 40–240 ms" })
    }
}

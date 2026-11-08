import UIKit

/// A GIF layer's frames above the canvas, as the Mac's timeline is under it: play and pause, how long each shows, the
/// frame in view counted, and a strip of thumbnails showing another. A long press duplicates or deletes a frame.
final class GIFTimelineView: MobileView, UICollectionViewDataSource, UICollectionViewDelegate {
    static let height: CGFloat = 76

    /// The tab in front's editor, whose GIF layer the strip shows.
    var session: EditorSession? {
        didSet {
            guard session !== oldValue else { return }
            stopPlayback()
            setNeedsUpdateProperties()
        }
    }

    private let play = UIButton(configuration: .plain())
    private let timing = UIButton(type: .system)
    private let count = UILabel()
    private let list: UICollectionView
    private var frames: [GIFTimelineFrame] = []
    private var selected = 0
    private var isPlaying = false
    private var playback: Task<Void, Never>?

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 56, height: 66)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        list = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        backgroundColor = Palette.window
        play.accessibilityLabel = "Play".localized
        play.widthAnchor.constraint(equalToConstant: 44).isActive = true
        play.heightAnchor.constraint(equalToConstant: 44).isActive = true
        play.addAction(UIAction { [weak self] _ in self?.togglePlayback() }, for: .primaryActionTriggered)
        timing.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timing.showsMenuAsPrimaryAction = true
        timing.setContentHuggingPriority(.required, for: .horizontal)
        count.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        count.textColor = .secondaryLabel
        list.backgroundColor = .clear
        list.dataSource = self
        list.delegate = self
        list.showsHorizontalScrollIndicator = false
        list.heightAnchor.constraint(equalToConstant: 66).isActive = true
        list.register(GIFFrameCell.self, forCellWithReuseIdentifier: "frame")
        let row = OptionControls.row([play, timing, count, list])
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8), row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateProperties() {
        super.updateProperties()
        guard let session else { return }
        frames = session.gifTimelineFrames
        selected = session.gifTimelineSelectedFrameIndex
        count.text = position.map { "\($0 + 1)/\(frames.count)" } ?? ""
        play.isEnabled = session.gifTimelineCanPlay
        let playing = session.gifTimelineIsPlaying
        play.configuration?.image = UIImage(systemName: playing ? "pause.fill" : "play.fill")
        timing.isEnabled = session.gifTimelineCanEditTiming
        updateTimingMenu(session.gifTimelineTiming)
        if playing != isPlaying {
            isPlaying = playing
            if playing { startPlayback() } else { stopPlayback() }
        }
        list.reloadData()
        if let position { list.scrollToItem(at: IndexPath(item: position, section: 0), at: .centeredHorizontally, animated: false) }
    }

    /// Where the frame in view is in the strip.
    private var position: Int? { frames.firstIndex { $0.index == selected } }

    private func togglePlayback() {
        guard let session, let layerID = session.gifTimelineLayerID else { return }
        session.toggleGIFPlayback(for: layerID)
        setNeedsUpdateProperties()
    }

    /// Shows the frames one after another, each for its own time, until paused or the layer goes, as the Mac's does.
    private func startPlayback() {
        guard let session, let layerID = session.gifTimelineLayerID else { return }
        let frames = session.gifTimelineFrames
        let timing = session.gifTimelineTiming
        let durations = frames.map { max(GIFTimelineLimits.minimumFrameDuration, timing.delay(for: $0)) }
        let initial = frames.firstIndex { $0.index == session.gifTimelineSelectedFrameIndex } ?? 0
        playback = Task { [weak self] in
            do {
                try await GIFPreviewPlayback.play(durations: durations, startingAt: initial) { position in
                    guard let self, let session = self.session else { return }
                    await session.selectGIFTimelineFrame(frames[position].index)
                    self.setNeedsUpdateProperties()
                }
            } catch is CancellationError {
            } catch { }
            guard let self, !Task.isCancelled else { return }
            session.stopGIFPlayback(for: layerID)
            self.setNeedsUpdateProperties()
        }
    }

    private func stopPlayback() {
        playback?.cancel()
        playback = nil
        isPlaying = false
    }

    // MARK: Timing

    /// Every frame for the same time, from a fast 20 ms up to a second, or each for the GIF's own, as the Mac's menu.
    private func updateTimingMenu(_ timing: GIFFrameTiming) {
        self.timing.setTitle(label(for: timing), for: .normal)
        let delay = uniformDelay(for: timing)
        let original = UIAction(title: "Original · \(originalDelays(timing, spaced: true))",
                                state: timing.mode == .uniform ? .off : .on) { [weak self] _ in
            guard let self, let session = self.session, let layerID = session.gifTimelineLayerID else { return }
            var changed = timing
            changed.mode = .perFrame
            session.setGIFFrameTiming(changed, for: layerID)
            self.setNeedsUpdateProperties()
        }
        let presets = [20, 33, 40, 50, 67, 80, 100, 125, 150, 200, 250, 500, 1000].map { milliseconds in
            UIAction(title: "\(milliseconds) ms · \(fps(milliseconds)) fps",
                     state: timing.mode == .uniform && Int(delay.rounded()) == milliseconds ? .on : .off) { [weak self] _ in
                guard let self, let session = self.session, let layerID = session.gifTimelineLayerID else { return }
                var changed = timing
                changed.mode = .uniform
                changed.uniformDelay = min(GIFFrameTiming.delayRange.upperBound, max(GIFFrameTiming.delayRange.lowerBound,
                                                                              Double(milliseconds) / 1000))
                session.setGIFFrameTiming(changed, for: layerID)
                self.setNeedsUpdateProperties()
            }
        }
        self.timing.menu = UIMenu(children: [original, UIMenu(options: .displayInline, children: presets)])
        self.timing.accessibilityLabel = "How long each frame shows".localized
    }

    /// The delay every frame shows for, in milliseconds: the one set here, or the GIF's own usual one.
    private func uniformDelay(for timing: GIFFrameTiming) -> Double {
        (timing.mode == .uniform ? timing.uniformDelay : GIFFrameTiming.defaultUniformDelay(for: frames)) * 1000
    }

    private func label(for timing: GIFFrameTiming) -> String {
        timing.mode == .uniform ? "\(Int(uniformDelay(for: timing).rounded()))ms" : originalDelays(timing, spaced: false)
    }

    /// The GIF's own delays: one, or the shortest to the longest when its frames differ.
    private func originalDelays(_ timing: GIFFrameTiming, spaced: Bool) -> String {
        let delays = frames.map { Int(((timing.frameDelays[$0.index] ?? $0.duration) * 1000).rounded()) }
        guard let shortest = delays.min(), let longest = delays.max() else { return "" }
        return (shortest == longest ? "\(shortest)" : "\(shortest)–\(longest)") + (spaced ? " ms" : "ms")
    }

    private func fps(_ milliseconds: Int) -> String {
        (1000 / Double(milliseconds)).formatted(.number.precision(.fractionLength(0...1)))
    }

    // MARK: The strip

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { frames.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "frame", for: indexPath) as! GIFFrameCell
        let frame = frames[indexPath.item]
        cell.show(frame.thumbnail, number: indexPath.item + 1, selected: frame.index == selected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let session else { return }
        let index = frames[indexPath.item].index
        // A tap takes over from playing, as the Mac's click does.
        if session.gifTimelineIsPlaying, let layerID = session.gifTimelineLayerID { session.toggleGIFPlayback(for: layerID) }
        Task { [weak self] in
            await session.selectGIFTimelineFrame(index)
            self?.setNeedsUpdateProperties()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let session, let layerID = session.gifTimelineLayerID else { return nil }
        let index = frames[indexPath.item].index
        let canEdit = session.gifTimelineCanEditFrames
        let canDelete = canEdit && frames.count > 1
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Duplicate Frame".localized, attributes: canEdit ? [] : .disabled) { _ in
                    Task { await session.duplicateGIFFrame(at: index, for: layerID); self?.setNeedsUpdateProperties() }
                },
                UIAction(title: "Delete Frame".localized, attributes: canDelete ? [] : .disabled) { _ in
                    Task { await session.deleteGIFFrames(at: [index], for: layerID); self?.setNeedsUpdateProperties() }
                },
            ])
        }
    }
}

/// One frame of the strip: what it shows, and its place in the layer.
private final class GIFFrameCell: UICollectionViewCell {
    private let picture = UIImageView()
    private let number = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        picture.contentMode = .scaleAspectFit
        picture.layer.cornerRadius = 5
        picture.layer.cornerCurve = .continuous
        picture.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        number.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        number.textColor = .secondaryLabel
        for view in [picture, number] as [UIView] {
            contentView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            picture.topAnchor.constraint(equalTo: contentView.topAnchor), picture.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            picture.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), picture.heightAnchor.constraint(equalToConstant: 50),
            number.topAnchor.constraint(equalTo: picture.bottomAnchor), number.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ image: CGImage, number position: Int, selected: Bool) {
        picture.image = UIImage(cgImage: image)
        number.text = "\(position)"
        picture.layer.borderColor = selected ? tintColor.cgColor : UIColor.white.withAlphaComponent(0.12).cgColor
        picture.layer.borderWidth = selected ? 2 : 1
        number.textColor = selected ? .label : .secondaryLabel
    }
}

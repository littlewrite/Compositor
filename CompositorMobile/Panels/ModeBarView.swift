import UIKit

/// The bar along the bottom of a window too narrow for the rail: the tools, the adjustments, the filters, the Layers
/// panel and every command, as five modes. Each opens over the canvas rather than taking room from it, so the canvas
/// keeps the whole width.
final class ModeBarView: MobileView {
    /// The panels the bar offers, in the design's order.
    enum Mode: CaseIterable {
        case tools, adjustments, filters, layers, more

        var symbol: String {
            switch self {
            case .tools: "square.grid.2x2"
            case .adjustments: "circle.lefthalf.filled"
            case .filters: "camera.filters"
            case .layers: "square.3.layers.3d"
            case .more: "ellipsis.circle"
            }
        }

        var title: String {
            switch self {
            case .tools: "Tools"
            case .adjustments: "Adjust"
            case .filters: "Filter"
            case .layers: "Layers"
            case .more: "More"
            }
        }
    }

    static let height: CGFloat = 52

    var session: EditorSession? { didSet { if session !== oldValue { setNeedsUpdateProperties() } } }
    var onSelect: (Mode) -> Void = { _ in }
    /// The mode whose panel is out, drawn as the rail draws the tool in hand.
    var shownMode: Mode? { didSet { if shownMode != oldValue { setNeedsUpdateProperties() } } }

    private var buttons: [Mode: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.window
        clipsToBounds = true
        let line = UIView()
        line.backgroundColor = Palette.separator
        addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.alignment = .fill
        for mode in Mode.allCases {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: mode.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17))
            configuration.title = mode.title.localized
            configuration.imagePlacement = .top
            configuration.imagePadding = 3
            configuration.contentInsets = .zero
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .preferredFont(forTextStyle: .caption2)
                return outgoing
            }
            let button = UIButton(configuration: configuration)
            button.accessibilityLabel = mode.title.localized
            button.accessibilityTraits = .button
            button.addAction(UIAction { [weak self] _ in self?.onSelect(mode) }, for: .primaryActionTriggered)
            buttons[mode] = button
            row.addArrangedSubview(button)
        }
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor), line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor), line.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale)),
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateProperties() {
        super.updateProperties()
        let hasDocument = session?.document != nil
        for (mode, button) in buttons {
            let shown = shownMode == mode
            button.configuration?.baseForegroundColor = shown ? .tintColor : .label
            button.backgroundColor = shown ? UIColor.tintColor.withAlphaComponent(0.18) : .clear
            button.layer.cornerRadius = 9
            button.layer.cornerCurve = .continuous
            button.accessibilityTraits = shown ? [.button, .selected] : .button
            // Every mode but More needs a document to act on; More lists New Canvas and the rest without one.
            button.isEnabled = mode == .more || hasDocument == true
        }
    }
}

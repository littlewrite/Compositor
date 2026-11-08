import UIKit

/// File › Export As…, as the Mac's sheet: the flattened canvas written as PNG, JPEG, TIFF or PDF, at a size chosen here
/// without changing the document. Export… makes the file and offers it in the share sheet, as Export JPEG does.
final class ExportAsController: SizeDialogController {
    static let formats: [ExportFormat] = [.png, .jpeg, .tiff, .pdf, .psd]
    static let scaleChoices = ["25%", "50%", "75%", "100%", "200%"]
    /// From the Mac's sheet: a pixel a side, at the most, and no more pixels in all than an export allows.
    static let largestSide = DocumentLimits.maxSide

    let raster: ExportRaster
    /// The document's layers, which a PSD keeps as layers; without it a PSD is the flattened canvas.
    let snapshot: ProjectSnapshot?
    private(set) var format: ExportFormat
    private(set) var width: Int
    private(set) var height: Int
    private(set) var quality: Double
    private(set) var matte: PaletteColor
    /// The encoding Export… set going. Tests wait for it.
    private(set) var encoding: Task<Void, Never>?
    private let finish: (Data, ExportFormat) -> Void
    private let cancelled: () -> Void

    private let formatPicker = PopUpButton()
    private let scale = PopUpButton()
    private lazy var widthField = dimensionField("Width") { [weak self] in self?.setWidth(Int($0.rounded())) }
    private lazy var heightField = dimensionField("Height") { [weak self] in self?.setHeight(Int($0.rounded())) }
    private lazy var locked = OptionControls.checkbox("Lock aspect ratio") { [weak self] on in
        self?.lockedAspect = on
    }
    private(set) var lockedAspect = true
    private let qualitySlider = SliderField(caption: "Quality", unit: "%", sliderRange: 0...1, fieldRange: 0...1, fieldScale: 100,
                                            sensitivity: 0.005, sliderWidth: nil)
    private let matteWell = UIColorWell()
    private let note = SizeDialogController.note()

    init(raster: ExportRaster, snapshot: ProjectSnapshot? = nil, format: ExportFormat = .png,
         finish: @escaping (Data, ExportFormat) -> Void, cancelled: @escaping () -> Void) {
        self.raster = raster
        self.snapshot = snapshot
        self.format = Self.formats.contains(format) ? format : .png
        self.finish = finish
        self.cancelled = cancelled
        width = raster.image.width
        height = raster.image.height
        quality = JPEGExportController.startingOptions.quality
        matte = PaletteColor(red: 1, green: 1, blue: 1)
        super.init(title: "Export As".localized, confirm: "Export…".localized)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var takesBackground: Bool { format == .jpeg || format == .tiff || format == .pdf }
    private var valid: Bool {
        width >= 1 && height >= 1 && width <= Self.largestSide && height <= Self.largestSide
            && width * height <= DocumentLimits.maxSurfacePixels
    }

    override func viewDidLoad() {
        formatPicker.accessibilityLabel = "Format".localized
        formatPicker.onChoose = { [weak self] in self?.chooseFormat(ExportFormat(rawValue: $0) ?? .png) }
        scale.accessibilityLabel = "Scale".localized
        scale.onChoose = { [weak self] choice in
            guard let self, let percent = Int(choice.dropLast()) else { return }
            self.setScale(Double(percent) / 100)
        }
        qualitySlider.onChange = { [weak self] value in self?.setQuality(value) }
        matteWell.title = "Export Background".localized
        matteWell.supportsAlpha = false
        matteWell.selectedColor = UIColor(srgbRed: matte.red, green: matte.green, blue: matte.blue, alpha: 1)
        matteWell.addAction(UIAction { [weak self] _ in
            guard let self, let color = self.matteWell.selectedColor else { return }
            self.chooseMatte(color)
        }, for: .valueChanged)

        let preview = UIImageView(image: UIImage(cgImage: raster.image))
        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .black
        preview.layer.cornerRadius = 4
        preview.layer.masksToBounds = true
        preview.heightAnchor.constraint(equalToConstant: 180).isActive = true

        for view in [preview, OptionControls.row([OptionControls.caption("Format", color: .secondaryLabel), formatPicker]),
                     OptionControls.row([widthField, heightField, scale]),
                     locked, qualitySlider,
                     OptionControls.row([OptionControls.caption("Background", color: .secondaryLabel), matteWell]),
                     note] as [UIView] {
            content.addArrangedSubview(view)
        }
        super.viewDidLoad()
        // After the base's viewDidLoad puts the content in the view, where the two have an ancestor to relate.
        preview.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
    }

    override func refresh() {
        formatPicker.show([Self.formats.map(\.rawValue)], chosen: format.rawValue)
        scale.show([Self.scaleChoices], chosen: "\(Int(scalePercent * 100))%")
        widthField.show(Double(width))
        heightField.show(Double(height))
        locked.isSelected = lockedAspect
        qualitySlider.show(quality)
        // JPEG's quality and the color that fills transparency only matter to the formats that use them.
        qualitySlider.isHidden = format != .jpeg
        matteWell.superview?.isHidden = !takesBackground
        confirmButton.isEnabled = valid && encoding == nil
        note.text = valid ? "\(width) × \(height) pixels · " + (format == .psd ? "Layers · Transparency kept"
                          : format == .png ? "Transparency kept" : "Transparent areas filled")
                          : "Use sizes from 1 to \(Self.largestSide.formatted()) pixels a side, and at most "
                            + "\(DocumentLimits.maxSurfaceMegapixels) megapixels in all."
        note.textColor = valid ? .secondaryLabel : .systemOrange
        view.setNeedsLayout()
    }

    private var scalePercent: Double { Double(width) / Double(raster.image.width) }

    private func dimensionField(_ caption: String, onChange: @escaping (Double) -> Void) -> NumberField {
        let field = NumberField(caption: caption, width: 80, range: 1...Double(Self.largestSide))
        field.live = true
        field.onChange = onChange
        return field
    }

    func chooseFormat(_ format: ExportFormat) {
        guard Self.formats.contains(format) else { return }
        self.format = format
        refresh()
    }
    func setQuality(_ value: Double) {
        quality = min(1, max(0, value))
        refresh()
    }
    func chooseMatte(_ color: UIColor) {
        guard let sRGB = color.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = sRGB.components, c.count >= 3 else { return }
        matte = PaletteColor(red: min(1, max(0, c[0])), green: min(1, max(0, c[1])), blue: min(1, max(0, c[2])))
    }

    /// Both sides follow one, keeping the canvas's proportions, as the Mac's sheet does while its lock is on.
    func setWidth(_ value: Int) {
        let clamped = min(Self.largestSide, max(1, value))
        let ratio = Double(clamped) / Double(raster.image.width)
        width = clamped
        if lockedAspect { height = max(1, min(Self.largestSide, Int((Double(raster.image.height) * ratio).rounded()))) }
        refresh()
    }
    func setHeight(_ value: Int) {
        let clamped = min(Self.largestSide, max(1, value))
        let ratio = Double(clamped) / Double(raster.image.height)
        height = clamped
        if lockedAspect { width = max(1, min(Self.largestSide, Int((Double(raster.image.width) * ratio).rounded()))) }
        refresh()
    }
    func setScale(_ value: Double) {
        let clamped = max(0.01, value.isFinite ? value : 1)
        width = max(1, Int((Double(raster.image.width) * clamped).rounded()))
        height = max(1, Int((Double(raster.image.height) * clamped).rounded()))
        refresh()
    }

    override func confirm() {
        guard valid, encoding == nil else { return }
        confirmButton.isEnabled = false
        note.text = "Encoding…".localized
        note.textColor = .secondaryLabel
        let format = format, width = width, height = height
        encoding = Task { [weak self] in
            guard let self else { return }
            defer {
                self.encoding = nil
                self.refresh()
            }
            do {
                let sized = try await ImageExporter.shared.resized(raster, width: width, height: height)
                let data: Data
                switch format {
                case .png:
                    data = try await ImageExporter.shared.pngData(sized)
                case .jpeg:
                    var options = JPEGOptions()
                    options.quality = quality
                    options.red = matte.red
                    options.green = matte.green
                    options.blue = matte.blue
                    data = try await ImageExporter.shared.jpeg(sized, options: options).data
                case .tiff:
                    data = try await ImageExporter.shared.tiffData(sized, matte: matte.cgColor).data
                case .pdf:
                    data = try await ImageExporter.shared.pdfData(sized, background: matte.cgColor)
                case .psd:
                    if let snapshot {
                        data = try await ImageExporter.shared.layeredPSD(snapshot, merged: sized)
                    } else {
                        data = try await ImageExporter.shared.psdData(sized)
                    }
                default:
                    return
                }
                self.finish(data, format)
            } catch {
                self.note.text = error.localizedDescription
                self.note.textColor = .systemOrange
            }
        }
    }
    override func cancel() {
        encoding?.cancel()
        cancelled()
    }
}

private extension PaletteColor {
    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
